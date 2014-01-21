$LOAD_PATH.unshift './lib'

require 'rubygems'
require 'rake'
require 'resque-status'
require 'resque/tasks'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "resque-status"
    gem.version = Resque::Plugins::Status::VERSION
    gem.summary = %Q{resque-status is an extension to the resque queue system that provides simple trackable jobs.}
    gem.description = %Q{resque-status is an extension to the resque queue system that provides simple trackable jobs. It provides a Resque::Plugins::Status::Hash class which can set/get the statuses of jobs and a Resque::Plugins::Status class that when included provides easily trackable/killable jobs.}
    gem.email = "aaron@quirkey.com"
    gem.homepage = "http://github.com/quirkey/resque-status"
    gem.rubyforge_project = "quirkey"
    gem.authors = ["Aaron Quint"]
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::RubygemsDotOrgTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test

task :default => :test
