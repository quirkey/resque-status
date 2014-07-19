module ResqueStatus
  class StatusesController < ResqueStatus::ApplicationController
    layout 'resque_web/application'
    def show
      @status = Resque::Plugins::Status::Hash.get(params[:id])
      @polling = request.xhr?
      respond_to do |format|
        format.html
        format.json { render :json => @status.json }
      end
    end

    def index
      @start = params[:start].to_i
      @end = @start + (params[:per_page] || 20)-1
      @statuses = Resque::Plugins::Status::Hash.statuses(@start, @end)
      @size = Resque::Plugins::Status::Hash.count
      @polling = request.xhr?
      @has_killable = @statuses.select(&:killable?).size > 0
      respond_to do |format|
        format.html {render :layout => !request.xhr? }
      end
    end

    def kill
      ids = params[:ids] || Array(params[:id])
      ids.each do |id|
        Resque::Plugins::Status::Hash.kill(params[:id])
      end
      head :no_content
    end
  end
end
