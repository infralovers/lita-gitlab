require 'spec_helper'

describe Lita::Handlers::Gitlab, lita_handler: true, additional_lita_handlers: Lita::Handlers::Jenkins do
  let(:default_job_name_prefix) { 'ruby-immmr-blog' }
  let(:default_job_name_build) { "#{default_job_name_prefix}-deploy" }
  let(:default_job_name_deploy) { "#{default_job_name_prefix}-test" }
  let(:artifact_review_id) { 'b-38' }

  before do
    Lita.config.handlers.jenkins.url = 'http://10.61.61.22:8080'
    Lita.config.handlers.gitlab.default_room = '#baz'
    Lita.config.handlers.gitlab.channel_to_project_map = { 'shell' => default_job_name_prefix }
  end

  it { is_expected.to route_command('artifact builds').to(:builds) }
  it { is_expected.to route_command("artifact review #{artifact_review_id}").to(:review) }

  let(:room) { Lita::Room.create_or_update('shell') }

  describe 'artifact builds' do
    context 'when using default adapter' do
      before { send_command('artifact builds', from: room) }

      it 'replies with a list of builds' do
        expect(replies.last).to include(artifact_review_id)
      end
    end

    context 'when using slack adapter' do
      before do
        # Fake slack adapter
        registry.register_adapter(:slack, Lita::Adapters::Shell)
        send_command('artifact builds', from: room)
      end

      it 'replies with a list of builds' do
        expect(replies.last).to include(artifact_review_id)
      end
    end
  end

  describe 'artifact review' do
    context 'when using default adapter' do
      before { send_command("artifact review #{artifact_review_id}", from: room) }

      it 'replies with details about the review' do
        expect(replies.last).to include(default_job_name_build)
        expect(replies.last).to include(default_job_name_deploy)
      end
    end

    context 'when using slack adapter' do
      before do
        # Fake slack adapter
        registry.register_adapter(:slack, Lita::Adapters::Shell)
        send_command("artifact review #{artifact_review_id}", from: room)
      end

      it 'replies with details about the review' do
        expect(replies.last).to include(default_job_name_build)
        expect(replies.last).to include(default_job_name_deploy)
      end
    end
  end
end
