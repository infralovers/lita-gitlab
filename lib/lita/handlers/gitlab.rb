require 'jenkins_api_client'
require 'gitlab'

module Lita
  module Handlers
    # The Main Handler Class
    class Gitlab < Handler
      config :token
      config :default_room
      config :url, default: 'http://example.gitlab/'
      config :external_lita_endpoint, default: 'http://example.lita/'
      config :group, default: 'group_name'
      config :debug_channel, default: 'cicd-debug'
      config :channel_to_project_map, default: { 'shell' => 'shell' }
      config :deploy_target_url, default: 'http://target.local'

      BUILD_REGEX = /[\w\-\.\+\_]+/
      GITLAB_HANDLER_PATH = '/lita/gitlab'

      http.post GITLAB_HANDLER_PATH, :receive

      on :merge_request, :jenkins_build

      def jenkins_build(payload)
        jenkins_client.job.build(payload[:job_name], payload[:job_params])
      end

      def receive(request, response)
        # byebug
        @request = request
        Lita.logger.warn request.body.string
        targets = (GitlabHelper.target_rooms(request.params['targets']) << config.debug_channel).compact.uniq
        # targets = [config.debug_channel]
        dispatch_trigger(request, targets: targets)
        # send_message_to_rooms(format_message(GitlabHelper.parse_data(request)), targets)
        # FIXXME: add a try catch, don't send the stacktrace back
        response.write('ok')
      end

      route(/^artifact?\s+builds?/i,
            :builds,
            command: true,
            help: { 'artifact builds' => 'list artifact repositories' }
           )

      route(/^artifact?\s+review\s+#{BUILD_REGEX.source}?/i,
            :review,
            command: true,
            help: { 'artifact builds' => 'review artifact' }
           )

      def builds(response)
        url = nil
        response.message.source
        job_name = "#{config.channel_to_project_map[response.message.source.room_object.name]}-test"
        title = 'Artifact builds'
        text = render_template('builds', data: all_builds_with_artifact(job_name))

        reply_to_chat(response, title, text, url)
      end

      def all_builds_with_artifact(job_name)
        all_builds = jenkins_client.job.get_builds(job_name, tree: 'builds[number,artifacts[*],description,changeSet[*[*]]]')
        all_builds.select { |build| !build['artifacts'].empty? }
      end

      def review(response)
        artifact_id = response.args[1][2..-1]

        deploy_job_name = "#{config.channel_to_project_map[response.message.source.room_object.name]}-deploy"
        build_job_name = "#{config.channel_to_project_map[response.message.source.room_object.name]}-test"

        data = review_build(build_job_name, deploy_job_name, artifact_id)
        url = "#{config.deploy_target_url}#{deploy_job_name}-#{data[:deploy]['number']}/index.html"
        text = render_template('review', data: data, deploy_url: url)

        reply_to_chat(response, title, text, url)
      end

      def review_build(build_job_name, deploy_job_name, artifact_id)
        deploy_nr = jenkins_client.job.build(deploy_job_name,
                                             { 'ARTIFACT_BUILD_NUMBER' => "<SpecificBuildSelector><buildNumber>#{artifact_id}</buildNumber></SpecificBuildSelector>" },
                                             'build_start_timeout' => 120
                                            )
        build_data = jenkins_client.job.get_build_details(build_job_name, artifact_id)
        deploy_data = jenkins_client.job.get_build_details(deploy_job_name, deploy_nr)

        { build: build_data, deploy: deploy_data }
      end

      private

      def gitlab_client
        @gitlab ||= ::Gitlab.client(endpoint: "#{config.url}api/v3", private_token: config.token)
      end

      def jenkins_client
        @jenkins_client ||= JenkinsApi::Client.new(server_url: Lita.config.handlers.jenkins.url)
      end

      def jenkins_connection
        Faraday.new(Lita.config.handlers.jenkins.url)
      end

      def send_message_to_rooms(message, rooms)
        rooms.each do |room|
          target = Source.new(room: Lita::Room.find_by_name(room))
          robot.send_message(target, message)
        end if message
      end

      def dispatch_trigger(request, params)
        content = request.body.string
        event = request.env['HTTP_X_GITLAB_EVENT']
        data = GitlabHelper.parse_data(request)

        case data[:object_kind]
        when 'merge_request'
          if data[:object_attributes][:state] =~ /open/
            if !data[:object_attributes][:work_in_progress] || data[:object_attributes][:title].downcase.include?('[review]')
              data[:job_name] = GitlabHelper.choose_job(data)
              data[:job_params] = GitlabHelper.build_merge_request_data(data)
              send_message_to_rooms("Preparing to deploy *#{data[:object_attributes][:source_branch]}* of MR: #{data[:object_attributes][:url]}", params[:targets])
              robot.trigger(:merge_request, data)
            else
              send_message_to_rooms("== DEBUG ==> Skipping review for MR '#{data[:object_attributes][:title]}' (wip: #{data[:object_attributes][:work_in_progress]})", [config.debug_channel])  
            end
          end
          send_message_to_rooms("== DEBUG ==> handled merge_request for #{data.inspect}\n\n", [config.debug_channel])
        when 'jenkins_trigger'
          send_message_to_rooms("== DEBUG ==> handled jenkins_trigger for #{data.inspect}\n\n", [config.debug_channel])
          message = "#{data[:object_attributes][:message]}"
          gitlab_client.create_merge_request_note(data[:object_attributes][:gitlabTargetProjectId], 
                                                  data[:object_attributes][:gitlabMergeRequestId], 
                                                  message
                                                  )
          send_message_to_rooms(message , params[:targets])

        else
          send_message_to_rooms("== DEBUG ==> Doing nothing about #{data.inspect}]\n\n", [config.debug_channel])
          Lita.logger.warn "Doing nothing about #{data.inspect}"
        end
      end

      def trigger_job(job, event, body)
        http_resp = jenkins_connection.post("/project/#{job}") do |req|
          req.headers = {
            'Content-Type' => 'application/json',
            'X-Gitlab-Event' => event
          }
          req.body = body
        end
        Lita.logger.warn http_resp.inspect
        http_resp
      end

      def format_message(data)
        data.key?(:event_name) ? system_message(data) : web_message(data)
      end

      def system_message(data)
        interpolate_message "system.#{data[:event_name]}", data
      rescue => e

        Lita.logger.warn "Error formatting message: #{data.inspect}"
        Lita.logger.warn e.backtrace
      end

      def web_message(data)
        case data[:object_kind]
        when 'push'
          build_branch_message(data)
        when 'tag_push'
          'sorry we do not handle the tag_push event'
        when 'issue'
          build_issue_message(data)
        when 'note'
          'sorry we do not handle the note event'
        when 'merge_request'
          build_merge_message(data)
        when 'add_to_branch'
          build_branch_message(data)
        else
          'sorry we do not handle this unknown event'
        end
      rescue => e
        Lita.logger.warn "Error formatting message: #{data.inspect}"
        Lita.logger.warn e.backtrace
        Lita.logger.warn e.inspect
      end

      def build_issue_message(data)
        t "web.#{data[:object_kind]}.#{data[:object_attributes][:state]}", data[:object_attributes]
      end

      def build_branch_message(data)
        data[:link] = "<#{data[:repository][:homepage]}|#{data[:repository][:name]}>"
        data[:before] =~ /^0+$/ ? t('web.push.new_branch', data) : t('web.push.add_to_branch', data)
      end

      def build_merge_message(data)
        data[:object_attributes][:project] = data[:project]
        data[:object_attributes][:link] = "<#{data[:repository][:homepage]}|#{data[:object_attributes][:title]}>"
        t "web.#{data[:object_kind]}.#{data[:object_attributes][:state]}", data[:object_attributes]
      end

      def reply_with_attachment(response, *attachment_params)
        target = response.message.source.room_object || response.message.source.user
        robot.chat_service.send_attachment(target, Lita::Adapters::Slack::Attachment.new(*attachment_params))
      end

      def reply_to_chat(response, *attachment_params)
        case robot.config.robot.adapter
        when :slack
          reply_with_attachment(response, *attachment_params)
        else
          response.reply text
        end

        response.reply
      end
    end
    Lita.register_handler(Gitlab)
  end
end
