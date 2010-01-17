require 'resque'
require 'redisk'
require 'uuid'

module Resque
  class Status < Hash
    VERSION = '0.1.0'
    
    extend Resque::Helpers

    class << self
      
      def create(message = nil)
        uuid = generate_uuid
        set(uuid, message) if message
        redis.zadd(set_key, Time.now.to_i, uuid)
        redis.zremrangebyscore(set_key, 0, Time.now.to_i - @expire_in) if @expire_in
        uuid
      end

      def get(uuid)
        val = redis.get(status_key(uuid))
        val ? Resque::Status.new(uuid, decode(val)) : nil
      end

      def set(uuid, *messages)
        val = Resque::Status.new(uuid, *messages)
        redis.set(status_key(uuid), encode(val))
        if expire_in
          redis.expire(status_key(uuid), expire_in) 
        end
        val
      end
      
      def logger(uuid, options = {})
        Redisk::Logger.new(logger_key(uuid), options)
      end

      def statuses(num = -1)
        h = {}
        status_ids(num).each do |id|
          h[id] = get(id)
        end
        h
      end

      def status_ids(num = -1)
        redis.zrevrange set_key, 0, num
      end
      
      def kill(uuid)
        redis.sadd(kill_key, uuid)
      end
      
      def killed(uuid)
        redis.srem(kill_key, uuid)
      end
      
      def kill_ids
        redis.smembers(kill_key)
      end
      
      def should_kill?(uuid)
        redis.sismember(kill_key, uuid)
      end

      def status_key(uuid)
        "status:#{uuid}"
      end

      def set_key
        "_statuses"
      end

      def kill_key
        "_kill"
      end
      def logger_key(uuid)
        "_log:#{uuid}"
      end

      def generate_uuid
        UUID.generate(:compact)
      end

      def expire_in
        @expire_in
      end
      
      def expire_in=(seconds)
        @expire_in = seconds.nil? ? nil : seconds.to_i
      end

      def hash_accessor(name, options = {})
        options[:default] ||= nil 
        coerce = options[:coerce] ? ".#{options[:coerce]}" : ""
        module_eval <<-EOT
        def #{name}
          value = (self['#{name}'] ? self['#{name}']#{coerce} : #{options[:default].inspect})
          yield value if block_given?
          value
        end

        def #{name}=(value)
          self['#{name}'] = value
        end

        def #{name}?
          !!self['#{name}']
        end
        EOT
      end

    end

    hash_accessor :uuid
    hash_accessor :name
    hash_accessor :status
    hash_accessor :message
    hash_accessor :time

    hash_accessor :num
    hash_accessor :total

    def initialize(*args)
      super nil
      self['uuid'] = args.shift if args.length > 1
      base_status = {
        'time' => Time.now.to_i,
        'status' => 'queued'
      }
      status_hash = args.inject(base_status) do |final, m|
        m = {'message' => m} if m.is_a?(String)
        final.merge(m || {})
      end
      self.replace(status_hash)
    end
    
    def pct_complete
      t = (total == 0 || total.nil?) ? 1 : total
      (((num || 0).to_f / t.to_f) * 100).to_i
    end
    
    def time
      time? ? Time.at(self['time']) : nil
    end

    def inspect
      "#<Resque::Status #{uuid} #{super}>"
    end

  end
end