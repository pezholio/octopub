# == Schema Information
#
# Table name: datasets
#
#  id                :integer          not null, primary key
#  name              :string
#  url               :string
#  user_id           :integer
#  created_at        :datetime
#  updated_at        :datetime
#  repo              :string
#  description       :text
#  publisher_name    :string
#  publisher_url     :string
#  license           :string
#  frequency         :string
#  datapackage_sha   :text
#  owner             :string
#  owner_avatar      :string
#  build_status      :string
#  full_name         :string
#  certificate_url   :string
#  job_id            :string
#  publishing_method :integer          default("github_public"), not null
#

require 'rails_helper'
require 'support/odlifier_licence_mock'

describe Dataset, vcr: { :match_requests_on => [:host, :method] } do
  include_context 'odlifier licence mock'

  before(:each) do
    @user = create(:user)
    allow_any_instance_of(Octokit::Client).to receive(:repository?) { false }
    Sidekiq::Testing.inline!
  end

  after(:each) do
    Sidekiq::Testing.fake!
  end

  it "creates a valid public dataset" do
    dataset = create(:dataset, name: "My Awesome Dataset",
                     description: "An awesome dataset",
                     publisher_name: "Awesome Inc",
                     publisher_url: "http://awesome.com",
                     license: "OGL-UK-3.0",
                     frequency: "One-off",
                     user: @user)

    expect(dataset.publishing_method).to eq :github_public.to_s
    expect(dataset).to be_valid
    expect(dataset.restricted).to be false
  end

  it "returns an error if the repo already exists" do
    expect_any_instance_of(Octokit::Client).to receive(:repository?).with("#{@user.github_username}/my-awesome-dataset") { true }

    dataset = build(:dataset, name: "My Awesome Dataset",
                     description: "An awesome dataset",
                     publisher_name: "Awesome Inc",
                     publisher_url: "http://awesome.com",
                     license: "OGL-UK-3.0",
                     frequency: "One-off",
                     user: @user)

    expect(dataset).to_not be_valid
  end

  it "creates a repo in Github" do

    name = "My Awesome Dataset"
    html_url = "http://github.com/#{@user.name}/#{name.parameterize}"

    dataset = build(:dataset, :with_callback, user: @user, name: name)

    obj = double(GitData)
    expect(GitData).to receive(:create).with(@user.github_username, name, restricted: false, client: a_kind_of(Octokit::Client)) {

      expect(obj).to receive(:add_file) { nil }
      expect(obj).to receive(:save) { nil }
      expect(obj).to receive(:html_url) { html_url }
      expect(obj).to receive(:name) { name.parameterize }
      expect(obj).to receive(:full_name) { "#{@user.name.parameterize}/#{name.parameterize}" }
      obj
    }
    allow(GitData).to receive(:find).with(@user.github_username, name, client: a_kind_of(Octokit::Client)) {
      obj
    }

    jekyll_service = JekyllService.new(dataset, nil)

    allow_any_instance_of(Dataset).to receive(:complete_publishing)

    dataset.save
    CreateRepository.new.perform(dataset.id)
    dataset.reload

    expect(dataset.repo).to eq(name.parameterize)
    expect(dataset.url).to eq(html_url)



  end

  it "creates a repo with an organization" do
    name = "My Awesome Dataset"
    dataset = build(:dataset, :with_callback, user: @user, name: name, owner: "my-cool-organization")
    html_url = "http://github.com/#{@user.name}/#{name.parameterize}"
    obj = double(GitData)
    expect(GitData).to receive(:create).with('my-cool-organization', name, restricted: false, client: a_kind_of(Octokit::Client)) {

      expect(obj).to receive(:html_url) { html_url }
      expect(obj).to receive(:name) { name.parameterize }
      expect(obj).to receive(:full_name) { "my-cool-organization/#{name.parameterize}" }
      obj
    }
    allow(GitData).to receive(:find).with('my-cool-organization', name, client: a_kind_of(Octokit::Client)) {
      obj
    }

    expect_any_instance_of(JekyllService).to receive(:add_files_to_repo_and_push_to_github)
    expect_any_instance_of(Dataset).to receive(:complete_publishing)

    dataset.save
    CreateRepository.new.perform(dataset.id)
  end

  it "completes publishing" do
    dataset = build(:dataset)
    expect(RepoService).to receive(:fetch_repo)
    expect(dataset).to receive(:set_owner_avatar)
    expect(dataset).to receive(:publish_public_views).with(true)
    expect(dataset).to receive(:send_success_email)
    expect_any_instance_of(SendTweetService).to receive(:perform)
    dataset.complete_publishing
  end

  it "deletes a repo in github" do
    dataset = create(:dataset, user: @user, owner: "foo-bar")
    repo = double(GitData)
    expect(RepoService).to receive(:fetch_repo) { repo }
    expect(repo).to receive(:delete)

    dataset.destroy
  end

  it "sets the user's avatar" do
    dataset = create(:dataset, user: @user)
    expect(@user).to receive(:avatar) { 'http://example.com/avatar.png' }

    dataset.send(:set_owner_avatar)
    expect(dataset.owner_avatar).to eq('http://example.com/avatar.png')
  end

  it "sets the user's avatar even if owner == user" do
    dataset = create(:dataset, user: @user, owner: @user.github_username)
    expect(@user).to receive(:avatar) { 'http://example.com/avatar.png' }

    dataset.send(:set_owner_avatar)
    expect(dataset.owner_avatar).to eq('http://example.com/avatar.png')
  end

  it "sets the owner's avatar" do
    dataset = create(:dataset, user: @user, owner: 'my-cool-organization')
    expect(Rails.configuration.octopub_admin).to receive(:organization).with('my-cool-organization') {
      double = double(Sawyer::Resource)
      expect(double).to receive(:avatar_url) { 'http://example.com/my-cool-organization.png' }
      double
    }

    dataset.send(:set_owner_avatar)
    expect(dataset.owner_avatar).to eq('http://example.com/my-cool-organization.png')
  end

  it "generates a path" do
    dataset = build(:dataset, user: @user, repo: "repo")

    expect(dataset.path("filename")).to eq("filename")
    expect(dataset.path("filename", "folder")).to eq("folder/filename")
  end

  it "generates the correct config" do
    dataset = build(:dataset, frequency: "weekly")
    config = YAML.load dataset.config

    expect(config["update_frequency"]).to eq("weekly")
  end

  context 'creating certificates for public datasets' do

    before(:each) do
      @dataset = create(:dataset)
      @certificate_url = 'http://staging.certificates.theodi.org/en/datasets/162441/certificate.json'
      allow(@dataset).to receive(:full_name) { "theodi/blockchain-and-distributed-technology-landscape-research" }
      allow(@dataset).to receive(:gh_pages_url) { "http://theodi.github.io/blockchain-and-distributed-technology-landscape-research" }
    end
  end

  context "creating restricted datasets" do
    it "creates a valid dataset" do
      dataset = create(:dataset, name: "My Awesome Dataset",
                       description: "An awesome dataset",
                       publisher_name: "Awesome Inc",
                       publisher_url: "http://awesome.com",
                       license: "OGL-UK-3.0",
                       frequency: "One-off",
                       user: @user,
                       publishing_method: :github_private)

      expect(dataset).to be_valid
      expect(dataset.restricted).to be true
    end

    it "creates a private repo in Github" do
      name = "My Awesome Dataset"
      html_url = "http://github.com/#{@user.name}/#{name.parameterize}"

      dataset = build(:dataset, :with_callback, user: @user, name: name, publishing_method: :github_private)
      obj = double(GitData)
      expect(GitData).to receive(:create).with(@user.github_username, name, restricted: true, client: a_kind_of(Octokit::Client)) {
        expect(obj).to receive(:html_url) { html_url }
        expect(obj).to receive(:name) { name.parameterize }
        expect(obj).to receive(:full_name) { "#{@user.name.parameterize}/#{name.parameterize}" }
        obj
      }
      allow(GitData).to receive(:find).with(@user.github_username, name, client: a_kind_of(Octokit::Client)) {
        obj
      }

      expect_any_instance_of(JekyllService).to receive(:add_files_to_repo_and_push_to_github)
      expect_any_instance_of(Dataset).to receive(:complete_publishing)

      dataset.save
      CreateRepository.new.perform(dataset.id)
      dataset.reload

      expect(dataset.repo).to eq(name.parameterize)
      expect(dataset.url).to eq(html_url)
    end


    it "can make a private repo public" do  
      Dataset.set_callback(:update, :after, :make_repo_public_if_appropriate)

      # Create dataset

      name = "My Awesome Dataset"
      html_url = "http://github.com/#{@user.name}/#{name.parameterize}"
      dataset = build(:dataset, :with_callback, user: @user, name: name, publishing_method: :github_private)
      obj = double(GitData)
      expect(GitData).to receive(:create).with(@user.github_username, name, restricted: true, client: a_kind_of(Octokit::Client)) {
        expect(obj).to receive(:add_file).once { nil }
        expect(obj).to receive(:save) { nil }
        expect(obj).to receive(:html_url) { html_url }
        expect(obj).to receive(:name) { name.parameterize }
        expect(obj).to receive(:full_name) { "#{@user.name.parameterize}/#{name.parameterize}" }
        expect(obj).to receive(:make_public)
        obj
      }
      allow(GitData).to receive(:find).with(@user.github_username, name, client: a_kind_of(Octokit::Client)) {
        obj
      }

      expect_any_instance_of(Dataset).to receive(:complete_publishing)
      dataset.save
      CreateRepository.new.perform(dataset.id)

      # Update dataset and make public
      updated_dataset = Dataset.find(dataset.id)
      expect(updated_dataset.restricted).to be true

      expect(updated_dataset).to receive(:update_dataset_in_github).once
      expect_any_instance_of(JekyllService).to receive(:create_public_views).once
      updated_dataset.publishing_method = :github_public#!# = false

      updated_dataset.save
      expect(updated_dataset.restricted).to be false

      skip_callback_if_exists(Dataset, :update, :after, :make_repo_public_if_appropriate)
    end
  end
end

