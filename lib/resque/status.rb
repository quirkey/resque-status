require 'resque'
require 'redisk'
require 'uuid'

module Resque
  # Resque::Status is a Hash object that has helper methods for dealing with
  # the common status attributes. It also has a number of class methods for
  # creating/updating/retrieving status objects from Redis
  class Status < Hash
    VERSION = '0.2.4'

    extend Resque::Helpers

    # Create a status, generating a new UUID, passing the message to the status
    # Returns the UUID of the new status.
    def self.create(*messages)
      uuid = generate_uuid
      set(uuid, *messages)
      redis.zadd(set_key, Time.now.to_i, uuid)
      redis.zremrangebyscore(set_key, 0, Time.now.to_i - @expire_in) if @expire_in
      uuid
    end

    # Get a status by UUID. Returns a Resque::Status
    def self.get(uuid)
      val = redis.get(status_key(uuid))
      val ? Resque::Status.new(uuid, decode(val)) : nil
    end

    # set a status by UUID. <tt>messages</tt> can be any number of stirngs or hashes
    # that are merged in order to create a single status.
    def self.set(uuid, *messages)
      val = Resque::Status.new(uuid, *messages)
      redis.set(status_key(uuid), encode(val))
      if expire_in
        redis.expire(status_key(uuid), expire_in)
      end
      val
    end

    # clear statuses from redis passing an optional range. See `statuses` for info
    # about ranges
    def self.clear(range_start = nil, range_end = nil)
      status_ids(range_start, range_end).each do |id|
        redis.del(status_key(id))
        redis.zrem(set_key, id)
      end
    end

    # returns a Redisk::Logger scoped to the UUID. Any options passed are passed
    # to the logger initialization.
    #
    # Ensures that Redisk is logging to the same Redis connection as Resque.
    def self.logger(uuid, options = {})
      Redisk.redis = redis
      Redisk::Logger.new(logger_key(uuid), options)
    end

    def self.count
      redis.zcard(set_key)
    end

    # Return <tt>num</tt> Resque::Status objects in reverse chronological order.
    # By default returns the entire set.
    # @param [Numeric] range_start The optional starting range
    # @param [Numeric] range_end The optional ending range
    # @example retuning the last 20 statuses
    #   Resque::Status.statuses(0, 20)
    def self.statuses(range_start = nil, range_end = nil)
      status_ids(range_start, range_end).collect do |id|
        get(id)
      end.compact
    end

    # Return the <tt>num</tt> most recent status/job UUIDs in reverse chronological order.
    def self.status_ids(range_start = nil, range_end = nil)
      unless range_end && range_start
        # Because we want a reverse chronological order, we need to get a range starting
        # by the higest negative number.
        redis.zrevrange(set_key, 0, -1) || []
      else
        # Because we want a reverse chronological order, we need to get a range starting
        # by the higest negative number. The ordering is transparent from the API user's
        # perspective so we need to convert the passed params
        (redis.zrevrange(set_key, (range_start.abs), ((range_end || 1).abs)) || [])
      end
    end

    # Kill the job at UUID on its next iteration this works by adding the UUID to a
    # kill list (a.k.a. a list of jobs to be killed. Each iteration the job checks
    # if it _should_ be killed by calling <tt>tick</tt> or <tt>at</tt>. If so, it raises
    # a <tt>Resque::JobWithStatus::Killed</tt> error and sets the status to 'killed'.
    def self.kill(uuid)
      redis.sadd(kill_key, uuid)
    end

    # Remove the job at UUID from the kill list
    def self.killed(uuid)
      redis.srem(kill_key, uuid)
    end

    # Return the UUIDs of the jobs on the kill list
    def self.kill_ids
      redis.smembers(kill_key)
    end

    # Check whether a job with UUID is on the kill list
    def self.should_kill?(uuid)
      redis.sismember(kill_key, uuid)
    end

    # The time in seconds that jobs and statuses should expire from Redis (after
    # the last time they are touched/updated)
    def self.expire_in
      @expire_in
    end

    # Set the <tt>expire_in</tt> time in seconds
    def self.expire_in=(seconds)
      @expire_in = seconds.nil? ? nil : seconds.to_i
    end

    def self.status_key(uuid)
      "status:#{uuid}"
    end

    def self.set_key
      "_statuses"
    end

    def self.kill_key
      "_kill"
    end

    def self.logger_key(uuid)
      "_log:#{uuid}"
    end

    def self.generate_uuid
      UUID.generate(:compact)
    end

    def self.hash_accessor(name, options = {})
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

    STATUSES = %w{queued working completed failed killed}.freeze

    hash_accessor :uuid
    hash_accessor :name
    hash_accessor :status
    hash_accessor :message
    hash_accessor :time
    hash_accessor :options

    hash_accessor :num
    hash_accessor :total

    # Create a new Resque::Status object. If multiple arguments are passed
    # it is assumed the first argument is the UUID and the rest are status objects.
    # All arguments are subsequentily merged in order. Strings are assumed to
    # be messages.
    def initialize(*args)
      super nil
      base_status = {
        'time' => Time.now.to_i,
        'status' => 'queued'
      }
      base_status['uuid'] = args.shift if args.length > 1
      status_hash = args.inject(base_status) do |final, m|
        m = {'message' => m} if m.is_a?(String)
        final.merge(m || {})
      end
      self.replace(status_hash)
    end

    # calculate the % completion of the job based on <tt>status</tt>, <tt>num</tt>
    # and <tt>total</tt>
    def pct_complete
      case status
      when 'completed' then 100
      when 'queued' then 0
      else
        t = (total == 0 || total.nil?) ? 1 : total
        (((num || 0).to_f / t.to_f) * 100).to_i
      end
    end

    # Return the time of the status initialization. If set returns a <tt>Time</tt>
    # object, otherwise returns nil
    def time
      time? ? Time.at(self['time']) : nil
    end

    STATUSES.each do |status|
      define_method("#{status}?") do
        self['status'] === status
      end
    end

    # Can the job be killed? 'failed', 'completed', and 'killed' jobs cant be killed
    # (for pretty obvious reasons)
    def killable?
      !['failed', 'completed', 'killed'].include?(self.status)
    end

    unless method_defined?(:to_json)
      def to_json(*args)
        json
      end
    end

    # Return a JSON representation of the current object.
    def json
      h = self.dup
      h['pct_complete'] = pct_complete
      self.class.encode(h)
    end

    def inspect
      "#<Resque::Status #{super}>"
    end

  end
end
