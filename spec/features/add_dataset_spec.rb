require "rails_helper"
require 'features/user_and_organisations'
require 'support/odlifier_licence_mock'

feature "Add dataset page", type: :feature do
  include_context 'user and organisations'
  include_context 'odlifier licence mock'

  let(:data_file) { get_fixture_file('valid-schema.csv') }

  before(:each) do
    allow_any_instance_of(DatasetsController).to receive(:current_user) { @user }
    visit root_path
  end

  context "logged in visitor has schemas and" do

    before(:each) do
      good_schema_url = url_with_stubbed_get_for_fixture_file('schemas/good-schema.json')
      create(:dataset_file_schema, url_in_repo: good_schema_url, name: 'good schema', description: 'good schema description', user: @user)
      click_link "Add dataset"
      expect(page).to have_content "Dataset name"
    end

    scenario "can access add dataset page" do
      within 'form' do
        expect(page).to have_content @user.github_username
      end
    end

    scenario "can access add dataset page see they have the form options for a schema" do
      within 'form' do
        expect(page).to have_content "good schema"
        expect(page).to have_content "Or upload a new one"
        expect(page).to have_content "No schema required"
        expect(page).to have_content @user.github_username
      end
    end

  end

  context "logged in visitors has no schemas" do
    scenario "and can complete a simple dataset form without adding a schema" do
      click_link "Add dataset"

      allow(DatasetFile).to receive(:read_file_with_utf_8).and_return(File.read(data_file))
      allow_any_instance_of(JekyllService).to receive(:create_data_files) { nil }
      allow_any_instance_of(JekyllService).to receive(:create_jekyll_files) { nil }
      allow_any_instance_of(JekyllService).to receive(:push_to_github) { nil }
      allow_any_instance_of(Dataset).to receive(:publish_public_views) { nil }
      allow_any_instance_of(Dataset).to receive(:send_success_email) { nil }

      common_name = 'Fri1437'

      before_datasets = Dataset.count
      expect(page).to have_selector(:link_or_button, "Submit")
      within 'form' do
        expect(page).to have_content @user.github_username
        expect(page).to have_content "Upload a schema for this Data File"
        complete_form(page, common_name, data_file)
      end

      # Bypass sidekiq completely
      allow(CreateDataset).to receive(:perform_async) do |a,b,c,d|
        CreateDataset.new.perform(a,b,c,d)
      end

      click_on 'Submit'

      expect(page).to have_content "Your dataset has been queued for creation, and you should receive an email with a link to your dataset on Github shortly."
      expect(Dataset.count).to be before_datasets + 1
      expect(Dataset.last.name).to eq "#{common_name}-name"
      expect(Dataset.last.owner).to eq @user.github_username
    end

  end

  def complete_form(page, common_name, data_file, owner = nil, licence = nil)

    dataset_name = "#{common_name}-name"

    fill_in 'dataset[name]', with: dataset_name
    select(@user.github_username, from: '[dataset[owner]]')

    fill_in 'dataset[description]', with: "#{common_name}-description"
    fill_in 'dataset[publisher_name]', with: "#{common_name}-publisher-name"
    fill_in 'dataset[publisher_url]', with: "http://#{common_name}-publisher-url.example.com/"
    fill_in 'files[][title]', with: "#{common_name}-file-name"
    fill_in 'files[][description]', with: "#{common_name}-file-description"
    attach_file("[files[][file]]", data_file)
    expect(page).to have_selector("input[value='#{dataset_name}']")

  end
end

