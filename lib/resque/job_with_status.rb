require 'resque/status'

module Resque
  class JobWithStatus
    class Killed < RuntimeError; end
    
    attr_reader :uuid, :options

    def self.queue
      :statused
    end
    
    def self.create(options = {})
      self.enqueue(self, options)
    end
    
    def self.enqueue(klass, options = {})
      uuid = Resque::Status.create
      Resque.enqueue(klass, uuid, options)
      uuid
    end

    def self.perform(uuid, options = {})
      instance = new(uuid, options)
      instance.safe_perform!
      instance
    end

    def initialize(uuid, options = {})
      @uuid    = uuid
      @options = options
    end

    def safe_perform!
      perform
      completed unless status && status.status == 'completed'
    rescue Killed
      logger.info "Job #{self} Killed at #{Time.now}"
      Resque::Status.killed(uuid)
    rescue => e
      logger.error e
      failed("The task failed because of an error: #{e.inspect}")
      raise e
    end

    def logger
      @logger ||= Resque::Status.logger(uuid)
    end

    def status=(new_status)
      Resque::Status.set(uuid, *new_status)
    end
    
    def status
      Resque::Status.get(uuid)
    end

    def should_kill?
      Resque::Status.should_kill?(uuid)
    end

    def at(num, total, message, more = {})
      kill! if should_kill?
      set_status({
        'num' => num, 
        'total' => total, 
        'status' => 'working',
        'message' => message
      }, more)
    end

    def failed(message, more = {})
      set_status({
        'status' => 'failed',
        'message' => message
      }, more)
    end
    
    def completed(message = nil, more = {})
      set_status({
        'status' => 'completed',
        'message' => message || "Completed at #{Time.now}"
      }, more)
    end
    
    def kill!
      set_status({
        'status' => 'killed',
        'message' => "Killed"
      })
      raise Killed
    end

    def set_status(*args)
      self.status = [{'name'  => self.class.to_s}, args].flatten
    end
    
  end
end