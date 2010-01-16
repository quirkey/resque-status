require 'resque/status'

module Resque
  module StatusServer
    
    VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
    
    def self.registered(app)
      
      
      app.get '/statuses' do
        @statuses = Resque::Status.statuses
        status_view(:statuses)
      end
      
      app.helpers do
        def status_view(filename)
          erb(File.read(File.join(VIEW_PATH, "#{filename}.erb")))
        end
      end
      
      app.tabs << "Statuses"
    end

  end
end