require 'resque'

module Resque
  autoload :JobWithStatus, "#{File.dirname(__FILE__)}/job_with_status"
  module Plugins
    autoload :Status, "#{File.dirname(__FILE__)}/plugins/status"
  end
end
