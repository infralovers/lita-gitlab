module Lita
  module Handlers
    class Gitlab < Handler
      config :default_room
      config :url, default: 'http://example.gitlab/'
      config :group, default: 'group_name'

      http.post '/lita/gitlab', :receive

      def receive(request, _response)
        json_body = request.params['payload'] || extract_json_from_request(request)
        data = parse_payload(json_body)
        data[:project] = request.params['project']
        message = format_message(data)
        if message
          targets = request.params['targets'] || Lita.config.handlers.gitlab.default_room
          rooms = []
          targets.split(',').each do |param_target|
            rooms << param_target
          end
          rooms.each do |room|
            target = Source.new(room: Lita::Room.find_by_name(room))
            robot.send_message(target, message)
          end
        end
      end

      private

      def extract_json_from_request(request)
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
          'sorry we do not handle the this unknown event'
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
