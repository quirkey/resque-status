require 'resque'
require 'redisk'
require 'uuid'

module Resque
  class Status
    include Resque::Helpers
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
        val ? decode(val) : nil
      end
      
      def set(uuid, message)
        val = encode(message)
        redis.set(status_key(uuid), val)
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
      
    end
    
  end
end