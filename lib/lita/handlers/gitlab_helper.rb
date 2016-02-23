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

        if content[:object_kind].include? 'merge_request'
          # If so, check it's title for a [review] tag and rename the job
          chosen_job << '-review' # if content[:object_attributes][:title].downcase.include? '[review]'
        end

        chosen_job
      end

      def self.build_merge_request_data(data)
        {
          'externalLitaEndpoint' => URI.join(Lita.config.handlers.gitlab.external_lita_endpoint, Lita::Handlers::Gitlab::GITLAB_HANDLER_PATH).to_s,
          'gitlabTargetProjectId' => data[:object_attributes][:target_project_id],
          'gitlabTargetBranch' => data[:object_attributes][:target_branch],
          'gitlabSourceBranch' => data[:object_attributes][:source_branch],
          'gitlabSourceRepoURL' => data[:object_attributes][:source][:ssh_url],
          'gitlabSourceRepoName' => data[:object_attributes][:source][:name],
          'gitlabBranch' => '',
          'gitlabActionType' => 'MERGE',
          'gitlabMergeRequestTitle' => data[:object_attributes][:title],
          'gitlabMergeRequestId' => data[:object_attributes][:id],
          'gitlabMergeRequestAssignee' => data[:object_attributes][:assignee_id],
          'gitlabUserName' => data[:object_attributes][:last_commit][:author][:name],
          'gitlabUserEmail' => data[:object_attributes][:last_commit][:author][:email]
        }
      end
    end
  end
end
