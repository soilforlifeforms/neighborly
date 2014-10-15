require 'spec_helper'

describe ProjectsController do
  before{ Notification.unstub(:notify_once) }
  before{ controller.stub(:current_user).and_return(current_user) }
  render_views
  subject{ response }
  let(:project){ create(:project, state: 'draft') }
  let(:current_user){ nil }

  describe "POST create" do
    let(:project){ build(:project) }
    before do
      attrs = project.attributes
      attrs[:credit_type] = 'general_obligation'
      post :create, { project: attrs  }
    end

    context "when no user is logged in" do
      it{ expect(response).to redirect_to new_user_session_path }
    end

    context "when user is logged in" do
      let(:current_user){ create(:user) }
      it{ expect(response).to redirect_to success_project_path(project) }
    end
  end

  describe 'GET success' do
    let(:project){ create(:project) }

    context 'when current user is the owner' do
      let(:current_user){ project.user }

      it 'responds with successful response' do
        get :success, id: project
        expect(response).to be_success
      end
    end

    context 'when current user is not the project owner' do
      let(:current_user){ create(:user) }

      it 'denies access for the page' do
        get :success, id: project
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET index' do
    before do
      controller.stub(:last_tweets).and_return([])
      get :index
    end
    it { expect(response).to be_success }

    describe 'staging env' do
      before do
        request.stub(:protocol).and_return("http://")
        request.stub(:host).and_return("staging.neighbor.ly")
        request.stub(:port).and_return(80)
        request.stub(:port_string).and_return(":80")
        request.stub(:path).and_return("/")
      end

      it 'should require basic auth' do
        get :index
        expect(response.status).to eq 401
      end
    end

    describe 'users without email' do
      let(:current_user) { create(:user, email: "change-your-email+#{Time.now.to_i}@neighbor.ly") }

      before do
        get :index
      end

      it { expect(response).to redirect_to set_email_users_path }
    end

    context 'project variables' do
      #vars = %i(featured recommended successful ending_soon coming_soon)
      vars = %i(recommended)

      vars.each do |var|
        it "should set #{var} as a instance variable" do
          expect(assigns(var)).to eq([])
        end
      end
    end
  end

  describe 'GET budget' do
    before do
      get :budget, id: project
    end
    it { expect(response).to be_success }
    it { expect(assigns(:project)).to eq project }
  end

  describe 'GET statement' do
    before do
      get :statement, id: project
    end
    let(:current_user) { create(:user, :beta) }

    it { expect(response).to be_success }
    it { expect(assigns(:project)).to eq project }
  end

  describe 'GET reports' do
    before do
      get :reports, id: project
    end

    context "when user is logged in" do
      let(:current_user){ project.user }
      it{ expect(response).to be_success }
    end

    context "when user is not logged in" do
      let(:current_user){ nil }
      it { expect(response).to redirect_to new_user_session_path }
    end
  end

  describe "GET new" do
    before { get :new }

    context "when acessing without be logged in" do
      it { expect(response).not_to be_success }
    end

    context "when acessing as logged in" do
      let(:current_user){ create(:user, admin: false) }
      it { expect(response).to be_success }
    end
  end

  describe "GET edit" do
    let(:project) { create(:project) }
    before { get :edit, id: project }

    context "when acessing without be logged in" do
      let(:current_user){ nil }
      it { expect(response).not_to be_success }
    end

    context "when acessing as logged in" do
      let(:current_user){ create(:user, admin: true) }
      it {  expect(response).to be_success }
    end
  end

  describe "GET edit" do
    let(:project) { create(:project) }
    before { get :edit, id: project }

    context "when acessing without be logged in" do
      let(:current_user){ nil }
      it { should_not be_success }
    end

    context "when acessing as logged in" do
      let(:current_user){ create(:user, admin: true) }
      it { should be_success }
    end
  end

  describe "PUT update" do
    shared_examples_for "updatable project" do
      before { put :update, id: project, project: { name: 'My Updated Title' },locale: :pt }
      it {
        project.reload
        expect(project.name).to eq 'My Updated Title'
      }

      it{ expect(response).to redirect_to edit_project_path(project) }
    end

    shared_examples_for "protected project" do
      before { put :update, id: project, project: { name: 'My Updated Title' },locale: :pt }
      it {
        project.reload
        expect(project.name).to eq 'Foo bar'
      }
    end

    context "when acessing without be logged in" do
      it_should_behave_like "protected project"
    end

    context "when user is a project owner" do
      let(:current_user){ project.user }

      context "when project is offline" do
        it_should_behave_like "updatable project"
      end

      context "when project is online" do
        let(:project) { create(:project, state: 'online') }

        before do
          controller.stub(:current_user).and_return(project.user)
        end

        context "when I try to update the project name field" do
          before{ put :update, id: project, project: { name: 'new_title' } }
          it "should not update neither" do
            project.reload
            expect(project.name).not_to eq 'new_title'
          end
        end

        context "when I try to update only the summary field" do
          before{ put :update, id: project, project: { summary: 'new_description' } }
          it "should update it" do
            project.reload
            expect(project.summary).to eq 'new_description'
          end
        end
      end
    end

    context "when acessing as logged in" do
      let(:current_user){ create(:user, admin: false) }
      it_should_behave_like "protected project"
    end

    context "when user is an admin" do
      let(:current_user){ create(:user, admin: true) }
      it_should_behave_like "updatable project"
    end
  end

  describe "GET embed" do
    before do
      get :embed, id: project
    end
    it { expect(response).to be_success }
  end

  describe "GET embed_panel" do
    before do
      get :embed_panel, id: project
    end
    it { expect(response).to be_success }
  end

  describe "GET show" do
    let(:current_user) { create(:user) }

    context 'when the project is on draft' do
      before do
        get :show, id: project
      end
      it { expect(response).to redirect_to(root_path) }
    end

    context 'when the project is not on draft' do
      before do
        project.launch
        project.reload
        get :show, id: project
      end
      it { expect(response).to be_success }
    end
  end
end
