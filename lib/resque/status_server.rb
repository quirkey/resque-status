require 'resque/status'

module Resque
  module StatusServer
    
    VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
    
    def self.registered(app)
      
      app.get '/statuses' do
        @start = params[:start].to_i
        @end = @start + (params[:per_page] || 50)
        @statuses = Resque::Status.statuses(@start, @end)
        @size = @statuses.size
        status_view(:statuses)
      end
      
      app.get '/statuses/:id.js' do
        @status = Resque::Status.get(params[:id])
        content_type :js
        @status.json
      end
      
      app.get '/statuses/:id' do
        @status = Resque::Status.get(params[:id])
        status_view(:status)
      end
      
      app.post '/statuses/:id/kill' do
        Resque::Status.kill(params[:id])
        redirect url(:statuses)
      end
      
      app.post '/statuses/clear' do
        Resque::Status.clear
        redirect url(:statuses)
      end
      
      app.get "/statuses.poll" do
        content_type "text/plain"
        @polling = true

        @statuses = Resque::Status.statuses
        status_view(:statuses, {:layout => false})
      end
      
      app.helpers do
        def status_view(filename, options = {}, locals = {})
          erb(File.read(File.join(::Resque::StatusServer::VIEW_PATH, "#{filename}.erb")), options, locals)
        end
      end
      
      app.tabs << "Statuses"
      
    end

  end
end

Resque::Server.register Resque::StatusServer
