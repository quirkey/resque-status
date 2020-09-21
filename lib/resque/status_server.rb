require 'resque/server'
require 'resque-status'

module Resque
  module StatusServer

    VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
    PER_PAGE = 50

    def self.registered(app)

      app.get '/statuses' do
        @filters = params[:filters]
        @start = params[:start].to_i
        @end = @start + (params[:per_page] || per_page) - 1
        @statuses = Resque::Plugins::Status::Hash.statuses(@start, @end)
        if @filters
          @statuses = @statuses.filter {|status| status.status == @filters[:status] } if @filters[:status]
          @statuses = @statuses.select { |job| job.name =~ /#{@filters[:job]}/i } if @filters[:job]
        end
        @size = Resque::Plugins::Status::Hash.count
        status_view(:statuses)
      end

      app.get '/statuses/:id.js' do
        @status = Resque::Plugins::Status::Hash.get(params[:id])
        content_type :js
        @status.json
      end

      app.get '/statuses/:id' do
        @status = Resque::Plugins::Status::Hash.get(params[:id])
        status_view(:status)
      end

      app.post '/statuses/:id/kill' do
        Resque::Plugins::Status::Hash.kill(params[:id])
        redirect u(:statuses)
      end

      app.post '/statuses/clear' do
        Resque::Plugins::Status::Hash.clear
        redirect u(:statuses)
      end

      app.post '/statuses/clear/completed' do
        Resque::Plugins::Status::Hash.clear_completed
        redirect u(:statuses)
      end

      app.post '/statuses/clear/failed' do
        Resque::Plugins::Status::Hash.clear_failed
        redirect u(:statuses)
      end

      app.get "/statuses.poll" do
        content_type "text/plain"
        @polling = true

        @start = params[:start].to_i
        @end = @start + (params[:per_page] || per_page) - 1
        @statuses = Resque::Plugins::Status::Hash.statuses(@start, @end)
        @size = Resque::Plugins::Status::Hash.count
        status_view(:statuses, {:layout => false})
      end

      app.helpers do
        def per_page
          PER_PAGE
        end

        def status_view(filename, options = {}, locals = {})
          erb(File.read(File.join(::Resque::StatusServer::VIEW_PATH, "#{filename}.erb")), options, locals)
        end

        def status_poll(start)
          if @polling
            text = "Last Updated: #{Time.now.strftime("%H:%M:%S")}"
          else
            text = "<a href='#{u(request.path_info)}.poll?start=#{start}' rel='poll'>Live Poll</a>"
          end
          "<p class='poll'>#{text}</p>"
        end
      end

      app.tabs << "Statuses"

    end

  end
end

Resque::Server.register Resque::StatusServer
