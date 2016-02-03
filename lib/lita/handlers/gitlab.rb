require 'jenkins_api_client'

module Lita
  module Handlers
    # The Main Handler Class
    class Gitlab < Handler
      config :default_room
      config :url, default: 'http://example.gitlab/'
      config :group, default: 'group_name'
      config :debug_channel, default: 'cicd-debug'
      config :channel_to_project_map, default: { 'shell' => 'shell' }

      BUILD_REGEX = /[\w\-\.\+\_]+/

      http.post '/lita/gitlab', :receive

      def receive(request, response)
        # byebug
        @request = request
        dispatch_trigger(request)
        send_message_to_rooms(format_message(GitlabHelper.parse_data(request)), GitlabHelper.target_rooms(request.params['targets']))
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
        text = render_template('builds', data: all_builds_with_artifact(job_name))

        case robot.config.robot.adapter
        when :slack
          title = 'Artifact builds'
          reply_with_attachment(response, url, title: title, fallback: text)
        else
          response.reply text
        end

        response.reply
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
        text = render_template('review', data: data)
        url = data[:deploy['number']]

        case robot.config.robot.adapter
        when :slack
          title = 'Click to Review Artifact'
          reply_with_attachment(response, url, title: title, fallback: text)
        else
          response.reply text
        end

        response.reply
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

      # def job_names
      #   Lita::Handlers::Jenkins.jobs.map { |job| job['name'] }
      # end

      # def job_details(job_name)
      #   HTTParty.get("#{SERVER}/job/#{job_name}/api/json")
      # end

      # def build_details(job_name, build_number)
      #   HTTParty.get("#{SERVER}/job/#{job_name}/#{build_number}/api/json")
      # end

      def dispatch_trigger(request)
        content = request.body.string
        event = request.env['HTTP_X_GITLAB_EVENT']
        data = GitlabHelper.parse_data(request)
        # make sure we do not trigger a build with a branch that was just deleted
        deleted = data[:deleted]

        if event.include? 'Note Hook'
          Lita.logger.warn data[:object_attributes][:note]
        elsif deleted
          Lita.logger.warn "branch #{branch} was deleted, not triggering build"
        else
          job = GitlabHelper.choose_job(data)
          Lita.logger.warn "Triggering #{job}"

          # if job_names.include? job
          trigger_job(job, event, content)
          # lse
          #  Lita.logger.warn "no such job #{job}"
          # end
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
    end
    Lita.register_handler(Gitlab)
  end
end
