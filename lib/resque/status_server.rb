require 'resque/status'

module Resque
  class StatusServer
    
    def self.registered(app)
      
      app.get '/statuses' do
        @statuses = Resque::Status.statuses
        erb File.join(File.dirname(__FILE__), 'server', 'views', 'statuses.erb')
      end
      
    end

  end
end