module ResqueStatus
  class ClearController < ResqueStatus::ApplicationController
    def destroy
      params[:id] = nil if params[:id] == 'all'
      Resque::Plugins::Status::Hash.clear(params[:id])
      head :no_content
    end
  end
end
