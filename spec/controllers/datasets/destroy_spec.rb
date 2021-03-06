require 'rails_helper'

describe DatasetsController, type: :controller do

  before(:each) do
    @user = create(:user)
  end

  describe 'destroy' do
    it 'deletes a dataset' do
      sign_in @user

      @dataset = create(:dataset, user: @user)

      expect(Dataset).to receive(:find).with(@dataset.id.to_s) {
        @dataset
      }

      expect(RepoService).to receive(:fetch_repo)
      expect(@dataset).to receive(:destroy)

      request = delete :destroy, params: { id: @dataset.id }
      expect(request).to redirect_to(dashboard_path)
      expect(flash[:notice]).to eq("Dataset '#{@dataset.name}' deleted sucessfully")
    end
  end

end
