module Resque
  class JobWithStatus
    include Resque::Plugins::Status
  end
end
