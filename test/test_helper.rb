dir = File.dirname(File.expand_path(__FILE__))
$LOAD_PATH.unshift dir + '/../lib'
$TESTING = true
require 'test/unit'
require 'rubygems'
require 'shoulda'
require 'mocha/setup'

require 'resque-status'

class Test::Unit::TestCase
end

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

at_exit do
  next if $!

  if defined?(MiniTest)
    exit_code = MiniTest::Unit.new.run(ARGV)
  else
    exit_code = Test::Unit::AutoRunner.run
  end

  pid = `ps -e -o pid,command | grep [r]edis-test`.split(" ")[0]
  puts "Killing test redis server..."
  Process.kill("KILL", pid.to_i)
  exit exit_code
end

puts "Starting redis for testing at localhost:9736..."
`rm -f #{dir}/dump.rdb && redis-server #{dir}/redis-test.conf`
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

class AtCallbackJob
  include Resque::Plugins::Status

  # Remember, 'at' shares 'tick' callbacks
  after_tick :report
  
  def report msg
    puts "This is my message: #{msg}"
  end

  def perform    
    at(1, 1, "report_message")
  end
end

class KilledCallbackJob
  include Resque::Plugins::Status

  after_killed :report
  
  def report msg
    puts "Dramatic death scene goes here"
  end

  def perform    
    self.kill!
  end
end

class CompletedCallbackJob
  include Resque::Plugins::Status

  after_completed :report
  
  def report msg
    puts msg
  end

  def perform    
    self.completed "Whether through good times or bad, our journey is at an end"
  end
end