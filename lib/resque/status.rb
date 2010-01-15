require 'resque'
require 'redisk'
require 'uuid'

module Resque
  class Status < Hash
    extend Resque::Helpers

    class << self

      def create(message = nil)
        uuid = generate_uuid
        set(uuid, message) if message
        redis.zadd(set_key, Time.now.to_i, uuid)
        uuid
      end

      def get(uuid)
        val = redis.get(status_key(uuid))
        val ? Resque::Status.new(uuid, decode(val)) : nil
      end

      def set(uuid, *messages)
        val = Resque::Status.new(uuid, *messages)
        redis.set(status_key(uuid), encode(val))
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

      def status_key(uuid)
        "status:#{uuid}"
      end

      def set_key
        "_statuses"
      end

      def logger_key(uuid)
        "_log:#{uuid}"
      end

      def generate_uuid
        UUID.generate(:compact)
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
    hash_accessor :status
    hash_accessor :message
    hash_accessor :time

    hash_accessor :num
    hash_accessor :total
    hash_accessor :pct_complete

    def initialize(*args)
      super({})
      if args.length > 1
        self['uuid'] = args.shift
      end
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

    def inspect
      "#<Resque::Status #{uuid} #{super}>"
    end

  end
end