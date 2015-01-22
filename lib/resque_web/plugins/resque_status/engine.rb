module ResqueWeb
  module Plugins
    module ResqueStatus
      class Engine < ::Rails::Engine
        # isolate or not?
        isolate_namespace ::ResqueStatus
        initializer "resque_status.assets.precompile" do |app|
          app.config.assets.precompile += %w(resque_status/application.css resque_status/application.js.coffee)
        end
      end

      def self.engine_path
        '/statuses'
      end

      def self.tabs
        [{'Status' => Engine.app.url_helpers.statuses_path}]
      end
    end
  end
end
