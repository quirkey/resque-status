require 'resque/status'

module Resque
  module StatusServer
    
    VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
    
    def self.registered(app)
      
      app.get '/statuses' do
        @statuses = Resque::Status.statuses
        status_view(:statuses)
      end
      
      app.get '/statuses/:id.js' do
        @status = Resque::Status.get(params[:id])
        content_type :js
        @status.to_json
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
          erb(File.read(File.join(VIEW_PATH, "#{filename}.erb")), options, locals)
        end
      end
      
      app.tabs << "Statuses"
      
    end

  end
end

Resque::Server.register Resque::StatusServer
