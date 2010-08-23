require 'rubygems'
require 'rake'
require File.join(File.expand_path('.'), 'lib/resque/status')
require 'resque/tasks'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "resque-status"
    gem.version = Resque::Status::VERSION
    gem.summary = %Q{resque-status is an extension to the resque queue system that provides simple trackable jobs.}
    gem.description = %Q{resque-status is an extension to the resque queue system that provides simple trackable jobs. It provides a Resque::Status class which can set/get the statuses of jobs and a Resque::JobWithStatus class that when subclassed provides easily trackable/killable jobs.}
    gem.email = "aaron@quirkey.com"
    gem.homepage = "http://github.com/quirkey/resque-status"
    gem.rubyforge_project = "quirkey"
    gem.authors = ["Aaron Quint"]
    gem.add_dependency "uuid", ">=2.0.2"
    gem.add_dependency "resque", ">=1.3.1"
    gem.add_dependency "redisk", ">=0.2.1"
    gem.add_development_dependency "shoulda", ">=2.10.2"
    gem.add_development_dependency "mocha", ">=0.9.8"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
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

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "resque-status #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
