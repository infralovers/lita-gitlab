module Lita
  module Handlers
    class Gitlab < Handler
      config :default_room
      config :url, default: 'http://example.gitlab/'
      config :group, default: 'group_name'

      http.post '/lita/gitlab', :receive

      def receive(request, response)
        #byebug
        @request = request
        json_body = @request.body.string
        data = parse_payload(json_body)
        data[:project] = request.params['project']

        dispatch_trigger(request, json_body, data)
        send_message_to_rooms(format_message(data), target_rooms(request.params['targets']))
        response.write("ok")
      end

      private
      
      def jenkins_connection
        Faraday.new(Lita.config.handlers.jenkins.url)
      end

      def target_rooms(targets)
        targets ||= Lita.config.handlers.gitlab.default_room
        rooms = []
        targets.split(',').each do |param_target|
          rooms << param_target
        end
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

      def choose_job(content)
        chosen_job = content[:repository][:name]

        # Is it a merge request?
        if content[:object_kind].include? 'merge_request'
          # If so, check it's title for a [review] tag and rename the job
          chosen_job << '-review' if content[:object_attributes][:title].downcase.include? '[review]'
        end

        chosen_job
      end

      def dispatch_trigger(request, raw_body, data)
        content = raw_body
        #push = JSON.parse(content)
        event = request.env['HTTP_X_GITLAB_EVENT']

        # make sure we do not trigger a build with a branch that was just deleted
        deleted = data[:deleted]

        if event.include? 'Note Hook'
          Lita.logger.warn data[:object_attributes][:note]
        elsif deleted
          Lita.logger.warn "branch #{branch} was deleted, not triggering build"
        else
          job = choose_job(data)
          Lita.logger.warn "Triggering #{job}"

          #if job_names.include? job
            trigger_job(job, event, content)
          #lse
          #  Lita.logger.warn "no such job #{job}"
          #end
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

      def request_body(request)
        request.body.rewind
        request.body.read
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
        interpolate_message "web.#{data[:object_kind]}.#{data[:object_attributes][:state]}", data[:object_attributes]
      end

      def build_branch_message(data)
        branch = data[:ref].split('/').drop(2).join('/')
        data[:link] = "<#{data[:repository][:homepage]}|#{data[:repository][:name]}>"
        if data[:before] =~ /^0+$/
          interpolate_message 'web.push.new_branch', data
        else
          interpolate_message 'web.push.add_to_branch', data
        end
      end

      def build_merge_message(data)
        url = Lita.config.handlers.gitlab.url.to_s
        url += if data[:project]
                 "#{Lita.config.handlers.gitlab.group}/#{data[:project]}/merge_requests/#{data[:object_attributes][:iid]}"
               else
                 "groups/#{Lita.config.handlers.gitlab.group}"
               end
        data[:object_attributes][:project] = data[:project]
        data[:object_attributes][:link] = "<#{url}|#{data[:object_attributes][:title]}>"
        interpolate_message "web.#{data[:object_kind]}.#{data[:object_attributes][:state]}", data[:object_attributes]
      end

      # General methods

      def interpolate_message(key, data)
        t(key) % data
      end

      def parse_payload(payload)
        MultiJson.load(payload, symbolize_keys: true)
      rescue MultiJson::LoadError => e
        Lita.logger.error("Could not parse JSON payload from Github: #{e.message}")
        return
      end
    end

    Lita.register_handler(Gitlab)
  end
end
