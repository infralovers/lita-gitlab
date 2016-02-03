module Lita
  module Handlers
    # Some Helper methods to clean up the main class
    class GitlabHelper
      def self.target_rooms(targets)
        targets ||= Lita.config.handlers.gitlab.default_room
        rooms = []
        targets.split(',').each do |param_target|
          rooms << param_target
        end
      end

      def self.parse_data(request)
        data = MultiJson.load(request.body.string, symbolize_keys: true)
        data[:project] = request.params['project']
        data
      rescue MultiJson::LoadError => e
        Lita.logger.error("Could not parse JSON payload from Github: #{e.message}")
        return
      end

      def self.choose_job(content)
        chosen_job = content[:repository][:name]

        # Is it a merge request?
        if content[:object_kind].include? 'merge_request'
          # If so, check it's title for a [review] tag and rename the job
          chosen_job << '-review' if content[:object_attributes][:title].downcase.include? '[review]'
        end

        chosen_job
      end
    end
  end
end
