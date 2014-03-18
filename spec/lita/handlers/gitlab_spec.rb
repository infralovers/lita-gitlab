require 'spec_helper'

describe Lita::Handlers::Gitlab, lita_handler: true do

  http_route_path = '/lita/gitlab'

  it 'registers with Lita' do
    expect(Lita.handlers).to include(described_class)
  end

  it "registers HTTP route POST #{http_route_path} to :receive" do
    routes_http(:post, http_route_path).to(:receive)
  end

  before :each do
    #Lita.config.handlers.gitlab.webhook_token = "aN1NvAlIdDuMmYt0k3n"
    #Lita.config.handlers.gitlab.team_domain = "example"
    #Lita.config.handlers.gitlab.ignore_user_name = "lita"
  end

  let(:request) do
    request = double('Rack::Request')
    allow(request).to receive(:params).and_return(params)
    request
  end
  let(:response) { Rack::Response.new }
  let(:params) { double('Hash') }
  let(:matchers) {
    {
      new_team_member: 'join',
      project_created: 'created',
      project_destroyed: 'destroyed',

    }
  }

  describe '#receive' do

    #context 'when system hook' do
    #
    #  context 'when new team member' do
    #    let(:new_team_member_payload) { fixture_file('system/new_team_member') }
    #    before do
    #      #Lita.config.handlers.gitlab.repos['milo-ft/testing'] = '#baz'
    #      allow(params).to receive(:[]).with('payload').and_return(new_team_member_payload)
    #      allow(response).to receive(:body).and_return(new_team_member_payload)
    #    end
    #
    #    it 'notifies to the applicable rooms' do
    #      expect(robot).to receive(:send_message) do |target, message|
    #        expect(target.room).to eq('#baz')
    #        puts matchers[:new_team_member]
    #        expect(message).to include matchers[:new_team_member]
    #      end
    #      subject.receive(request, response)
    #    end
    #  end
    #
    #  context 'when project created' do
    #    let(:project_created_payload) { fixture_file('system/project_created') }
    #    before do
    #      Lita.config.handlers.gitlab.repos['milo-ft/testing'] = '#baz'
    #      allow(params).to receive(:[]).with('payload').and_return(new_team_member_payload)
    #    end
    #
    #    it 'notifies to the applicable rooms' do
    #      expect(robot).to receive(:send_message) do |target, message|
    #        expect(target.room).to eq('#baz')
    #        expect(message).to include matchers[:project_created]
    #      end
    #      subject.receive(request, response)
    #    end
    #  end
    #
    #  context 'when project destroyed' do
    #  let(:project_destroyed_payload) { fixture_file('system/project_destroyed') }
    #  before do
    #    Lita.config.handlers.gitlab.repos['milo-ft/testing'] = '#baz'
    #    allow(params).to receive(:[]).with('payload').and_return(new_team_member_payload)
    #  end
    #
    #  it 'notifies to the applicable rooms' do
    #    expect(robot).to receive(:send_message) do |target, message|
    #      expect(target.room).to eq('#baz')
    #      expect(message).to include matchers[:project_destroyed]
    #    end
    #    subject.receive(request, response)
    #  end
    #end
    #end
    #
    #context 'when web project hook' do
    #
    #  context 'when issue event' do
    #    let(:issue_payload) { fixture_file('web/issue') }
    #    before do
    #      Lita.config.handlers.gitlab.repos['milo-ft/testing'] = '#baz'
    #      allow(params).to receive(:[]).with('payload').and_return(issue_payload)
    #    end
    #
    #    it 'notifies to the applicable rooms' do
    #      expect(robot).to receive(:send_message) do |target, message|
    #        expect(target.room).to eq('#baz')
    #        expect(message).to include 'new issue'
    #      end
    #      subject.receive(request, response)
    #    end
    #  end
    #
    #  context 'when push event' do
    #    let(:push_payload) { fixture_file('web/push') }
    #    before do
    #      Lita.config.handlers.gitlab.repos['milo-ft/testing'] = '#baz'
    #      allow(params).to receive(:[]).with('payload').and_return(push_payload)
    #    end
    #
    #    it 'notifies to the applicable rooms' do
    #      expect(robot).to receive(:send_message) do |target, message|
    #        expect(target.room).to eq('#baz')
    #        expect(message).to include 'new push'
    #      end
    #      subject.receive(request, response)
    #    end
    #  end
    #
    #  context 'when merge request event' do
    #    let(:merge_request_payload) { fixture_file('web/merge_request') }
    #    before do
    #      Lita.config.handlers.gitlab.repos['milo-ft/testing'] = '#baz'
    #      allow(params).to receive(:[]).with('payload').and_return(merge_request_payload)
    #    end
    #
    #    it 'notifies to the applicable rooms' do
    #      expect(robot).to receive(:send_message) do |target, message|
    #        expect(target.room).to eq('#baz')
    #        expect(message).to include 'new merge request'
    #      end
    #      subject.receive(request, response)
    #    end
    #  end
    #end
  end
end