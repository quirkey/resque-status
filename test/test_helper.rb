require "bundler/setup"
require "resque-status"

require "minitest/autorun"
require "mocha/setup"

require "fakeredis"
Resque.redis = Redis.new

#### Fixtures

class WorkingJob
  include Resque::Plugins::Status

  def perform
    total = options["num"]
    (1..total).each do |num|
      at(num, total, "At #{num}")
    end
  end
end

class ErrorJob
  include Resque::Plugins::Status

  def perform
    raise "I'm a bad little job"
  end
end

class KillableJob
  include Resque::Plugins::Status

  def perform
    Resque.redis.set("#{uuid}:iterations", 0)
    100.times do |num|
      Resque.redis.incr("#{uuid}:iterations")
      at(num, 100, "At #{num} of 100")
    end
  end
end

class BasicJob
  include Resque::Plugins::Status
end

class FailureJob
  include Resque::Plugins::Status

  def perform
    failed("I'm such a failure")
  end
end

class NeverQueuedJob
  include Resque::Plugins::Status

  def self.before_enqueue(*args)
    false
  end

  def perform
    # will never get called
  end
end
