require 'bundler/setup'
require 'resque-status'

require 'minitest/autorun'
require 'mocha/setup'
require 'timecop'

#
# make sure we can run redis
#

if !system("which redis-server")
  puts '', "** can't find `redis-server` in your path"
  puts "** try running `sudo rake install`"
  abort ''
end

#
# start our own redis when the tests start,
# kill it when they end
#


class << Minitest
  def exit(*args)
    pid = `ps -e -o pid,command | grep [r]edis.*9736`.split(" ")[0]
    puts "Killing test redis server..."
    Process.kill("KILL", pid.to_i)
    super
  end
end

dir = File.expand_path("../", __FILE__)
puts "Starting redis for testing at localhost:9736..."
result = `rm -f #{dir}/dump.rdb && redis-server #{dir}/redis-test.conf`
raise "Redis failed to start: #{result}" unless $?.success?
Resque.redis = 'localhost:9736/1'

#### Fixtures

class WorkingJob

  include Resque::Plugins::Status

  def perform
    total = options['num']
    (1..total).each do |num|
      at(num, total, "At #{num}")
    end
  end

end

class WorkingParentJob
  include Resque::Plugins::Status

  def perform
    init_parent(3)
    # This is a workaround to test killing job while it enqueues children with inline resque.
    # The real use case would be that the `kill` would happen somewhere in the middle of subjob runs,
    # long after the main job finished.
    Resque::Plugins::Status::Hash.kill(@uuid) if options['self_kill']
    3.times { |i| enqueue_child('job_num' => i) }
  end

  def perform_child
    Resque.redis.sadd('child_jobs_done', options['job_num'])
  end

  def on_success
    Resque.redis.sadd('child_on_success', options['job_num'] || 'parent')
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
