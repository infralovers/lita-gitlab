require 'spec_helper'

describe Lita::Handlers::Gitlab, lita_handler: true, additional_lita_handlers: Lita::Handlers::Jenkins do
  before do
    Lita.config.handlers.jenkins.url = 'http://jenkins.local:8080'
    Lita.config.handlers.gitlab.default_room = '#baz'
  end

  http_route_path = '/lita/gitlab'

  it 'registers with Lita' do
    expect(Lita.handlers).to include(described_class)
  end

  it "registers HTTP route POST #{http_route_path} to :receive" do
    is_expected.to route_http(:post, http_route_path).to(:receive)
  end

  let(:response) { Rack::Response.new }
  let(:params) { {} }
  let(:targets) { '#baz' }
  let(:project) { 'test_project' }
  let(:matchers) do
    {
      new_team_member: 'John Smith has joined to the StoreCloud project',
      project_created: 'John Smith has created the StoreCloud project!',
      project_destroyed: 'John Smith has destroyed the Underscore project!',
      issue_opened: 'New issue >> New API: create/update/delete file: Create new API for manipulations with repository',
      add_to_branch: "John Smith added 4 commits to branch '<http://localhost/diaspora|Diaspora>' in project test_project",
      merge_request_created: 'New merge-request #1 en test_project: <http://example.gitlab/group_name/test_project/merge_requests/1|MS-Viewport>'
    }
  end

  let(:room) { '#baz' }

  describe '#receive' do
    before :each do
      allow(Lita::Room).to receive(:find_by_name).and_return(room)
    end

    # context 'with system hook' do
    #   context 'when new team member' do
    #     let(:new_team_member_payload) { fixture_file('system/new_team_member') }

    #     before do
    #       allow(params).to receive(:[]).with('payload').and_return(new_team_member_payload)
    #     end

    #     it 'notifies to the applicable rooms' do
    #       expect(robot).to receive(:send_message) do |target, message|
    #         expect(target.room).to eq('#baz')
    #         expect(message).to eq matchers[:new_team_member]
    #       end
    #       subject.receive(request, response)
    #     end
    #   end

    #   context 'when project created' do
    #     let(:project_created_payload) { fixture_file('system/project_created') }
    #     before do
    #       allow(params).to receive(:[]).with('payload').and_return(project_created_payload)
    #     end

    #     it 'notifies to the applicable rooms' do
    #       expect(robot).to receive(:send_message) do |target, message|
    #         expect(target.room).to eq('#baz')
    #         expect(message).to eq matchers[:project_created]
    #       end
    #       subject.receive(request, response)
    #     end
    #   end

    #   context 'when project destroyed' do
    #     let(:project_destroyed_payload) { fixture_file('system/project_destroyed') }
    #     before do
    #       allow(params).to receive(:[]).with('payload').and_return(project_destroyed_payload)
    #     end

    #     it 'notifies to the applicable rooms' do
    #       expect(robot).to receive(:send_message) do |target, message|
    #         expect(target.room).to eq('#baz')
    #         expect(message).to eq matchers[:project_destroyed]
    #       end
    #       subject.receive(request, response)
    #     end
    #   end
    # end

    context 'when web project hook' do
      #   context 'when issue event' do
      #     let(:issue_payload) { fixture_file('web/issue_hook') }
      #     before do
      #       allow(params).to receive(:[]).with('payload').and_return(issue_payload)
      #     end

      #     it 'notifies to the applicable rooms' do
      #       expect(robot).to receive(:send_message) do |target, message|
      #         expect(target.room).to eq('#baz')
      #         expect(message).to eq matchers[:issue_opened]
      #       end
      #       subject.receive(request, response)
      #     end
      #   end

      #   context 'when push event' do
      #     let(:push_payload) { fixture_file('web/add_to_branch') }
      #     before do
      #       allow(params).to receive(:[]).with('payload').and_return(push_payload)
      #     end

      #     it 'notifies to the applicable rooms' do
      #       expect(robot).to receive(:send_message) do |target, message|
      #         expect(target.room).to eq('#baz')
      #         expect(message).to eq matchers[:add_to_branch]
      #       end
      #       subject.receive(request, response)
      #     end
      #   end

      context 'when merge request event' do
        let(:merge_request_created) { fixture_file('web/merge_request_created') }
        before do
          jenkins_connection do |stubs|
            stubs.post('/project/Diaspora', merge_request_created) { [200, {}, nil] }
          end
          expect_any_instance_of(Lita::Handlers::Gitlab).to receive(:trigger_job).with('Diaspora', any_args).and_call_original
          allow_any_instance_of(Lita::Handlers::Gitlab).to receive(:jenkins_connection).and_return(jenkins_connection)
        end

        it 'triggers the original jenkins project' do
          response = http.post('/lita/gitlab', targets: 'baz') do |req|
            req.headers = {
              'Content-Type' => 'application/json',
              'X-Gitlab-Event' => 'Merge Request Hook'
            }
            req.body = merge_request_created
          end
          expect(response.body).to eq('ok')
          expect(replies.last).to match(/merge-request/)
          @stubs.verify_stubbed_calls
        end
      end

      context 'when merge request event' do
        let(:merge_request_payload_with_review_in_title) { fixture_file('web/merge_request_created_with_review_in_title') }
        before do
          jenkins_connection do |stubs|
            stubs.post('/project/Diaspora-review', merge_request_payload_with_review_in_title) { [200, {}, nil] }
          end
          expect_any_instance_of(Lita::Handlers::Gitlab).to receive(:trigger_job).with('Diaspora-review', any_args).and_call_original
          allow_any_instance_of(Lita::Handlers::Gitlab).to receive(:jenkins_connection).and_return(jenkins_connection)
        end

        it 'triggers the review jenkins project' do
          response = http.post('/lita/gitlab', targets: 'baz') do |req|
            req.headers = {
              'Content-Type' => 'application/json',
              'X-Gitlab-Event' => 'Merge Request Hook'
            }
            req.body = merge_request_payload_with_review_in_title
          end
          expect(response.body).to eq('ok')
          expect(replies.last).to match(/merge-request/)

          @stubs.verify_stubbed_calls
        end
      end
    end
  end
end
