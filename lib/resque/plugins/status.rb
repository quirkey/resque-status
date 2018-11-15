module Resque
  module Plugins

    # Resque::Plugins::Status is a module your jobs will include.
    # It provides helper methods for updating the status/etc from within an
    # instance as well as class methods for creating and queuing the jobs.
    #
    # All you have to do to get this functionality is include Resque::Plugins::Status
    # and then implement a <tt>perform<tt> method.
    #
    # For example
    #
    #       class ExampleJob
    #         include Resque::Plugins::Status
    #
    #         def perform
    #           num = options['num']
    #           i = 0
    #           while i < num
    #             i += 1
    #             at(i, num)
    #           end
    #           completed("Finished!")
    #         end
    #
    #       end
    #
    # This job would iterate num times updating the status as it goes. At the end
    # we update the status telling anyone listening to this job that its complete.
    module Status
      VERSION = '0.5.0'

      STATUS_QUEUED = 'queued'
      STATUS_WORKING = 'working'
      STATUS_COMPLETED = 'completed'
      STATUS_FAILED = 'failed'
      STATUS_KILLED = 'killed'
      STATUSES = [
        STATUS_QUEUED,
        STATUS_WORKING,
        STATUS_COMPLETED,
        STATUS_FAILED,
        STATUS_KILLED
      ].freeze

      autoload :Hash, 'resque/plugins/status/hash'

      # The error class raised when a job is killed
      class Killed < RuntimeError; end
      class NotANumber < RuntimeError; end

      attr_reader :uuid, :options

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        # The default queue is :statused, this can be ovveridden in the specific job
        # class to put the jobs on a specific worker queue
        def queue
          :statused
        end

        # used when displaying the Job in the resque-web UI and identifiyng the job
        # type by status. By default this is the name of the job class, but can be
        # ovveridden in the specific job class to present a more user friendly job
        # name
        def name
          self.to_s
        end

        # Create is the primary method for adding jobs to the queue. This would be
        # called on the job class to create a job of that type. Any options passed are
        # passed to the Job instance as a hash of options. It returns the UUID of the
        # job.
        #
        # == Example:
        #
        #       class ExampleJob
        #         include Resque::Plugins::Status
        #
        #         def perform
        #           set_status "Hey I'm a job num #{options['num']}"
        #         end
        #
        #       end
        #
        #       job_id = ExampleJob.create(:num => 100)
        #
        def create(options = {})
          self.enqueue(self, options)
        end

        # Adds a job of type <tt>klass<tt> to the queue with <tt>options<tt>.
        #
        # Returns the UUID of the job if the job was queued, or nil if the job was
        # rejected by a before_enqueue hook.
        def enqueue(klass, options = {})
          self.enqueue_to(Resque.queue_from_class(klass) || queue, klass, options)
        end

        # Adds a job of type <tt>klass<tt> to a specified queue with <tt>options<tt>.
        #
        # Returns the UUID of the job if the job was queued, or nil if the job was
        # rejected by a before_enqueue hook.
        def enqueue_to(queue, klass, options = {})
          uuid = Resque::Plugins::Status::Hash.generate_uuid
          Resque::Plugins::Status::Hash.create uuid, :options => options

          if Resque.enqueue_to(queue, klass, uuid, options)
            uuid
          else
            Resque::Plugins::Status::Hash.remove(uuid)
            nil
          end
        end

        # Removes a job of type <tt>klass<tt> from the queue.
        #
        # The initially given options are retrieved from the status hash.
        # (Resque needs the options to find the correct queue entry)
        def dequeue(klass, uuid)
          status = Resque::Plugins::Status::Hash.get(uuid)
          Resque.dequeue(klass, uuid, status.options)
        end

        # This is the method called by Resque::Worker when processing jobs. It
        # creates a new instance of the job class and populates it with the uuid and
        # options.
        #
        # You should not override this method, rahter the <tt>perform</tt> instance method.
        def perform(uuid=nil, options = {})
          uuid ||= Resque::Plugins::Status::Hash.generate_uuid
          instance = new(uuid, options)
          instance.safe_perform!
          instance
        end

        # Wrapper API to forward a Resque::Job creation API call into a Resque::Plugins::Status call.
        # This is needed to be used with resque scheduler
        # http://github.com/bvandenbos/resque-scheduler
        def scheduled(queue, klass, *args)
          self.enqueue_to(queue, self, *args)
        end
      end

      # Create a new instance with <tt>uuid</tt> and <tt>options</tt>
      def initialize(uuid, options = {})
        @uuid    = uuid
        @options = options
      end

      # Run by the Resque::Worker when processing this job. It wraps the <tt>perform</tt>
      # method ensuring that the final status of the job is set regardless of error.
      # If an error occurs within the job's work, it will set the status as failed and
      # re-raise the error.
      def safe_perform!
        set_status({'status' => STATUS_WORKING})
        perform
        if status && status.failed?
          on_failure(status.message) if respond_to?(:on_failure)
          return
        elsif status && !status.completed?
          completed
        end
        on_success if respond_to?(:on_success)
      rescue Killed
        Resque::Plugins::Status::Hash.killed(uuid)
        on_killed if respond_to?(:on_killed)
      rescue Exception => e
        @options[:logger].info("<<RESQUE-STATUS>> ERROR(in: #{self.class} job)! #{e.class}: #{e.message}\n\t#{e.backtrace.join("\n\t")}\n\n\tinspect: #{inspect}\n\n") if @options[:logger]
        failed("The task failed because of an error: #{e}")
        if respond_to?(:on_failure)
          on_failure(e)
        else
          raise e
        end
      end

      # Set the jobs status. Can take an array of strings or hashes that are merged
      # (in order) into a final status hash.
      def status=(new_status)
        Resque::Plugins::Status::Hash.set(uuid, *new_status)
      end

      # get the Resque::Plugins::Status::Hash object for the current uuid
      def status
        Resque::Plugins::Status::Hash.get(uuid)
      end

      def name
        "#{self.class.name}(#{options.inspect unless options.empty?})"
      end

      # Checks against the kill list if this specific job instance should be killed
      # on the next iteration
      def should_kill?
        Resque::Plugins::Status::Hash.should_kill?(uuid)
      end

      # set the status of the job for the current itteration. <tt>num</tt> and
      # <tt>total</tt> are passed to the status as well as any messages.
      # This will kill the job if it has been added to the kill list with
      # <tt>Resque::Plugins::Status::Hash.kill()</tt>
      def at(num, total, *messages)
        if total.to_f <= 0.0
          raise(NotANumber, "Called at() with total=#{total} which is not a number")
        end
        tick({
          'num' => num,
          'total' => total
        }, *messages)
      end

      # sets the status of the job for the current itteration. You should use
      # the <tt>at</tt> method if you have actual numbers to track the iteration count.
      # This will kill the job if it has been added to the kill list with
      # <tt>Resque::Plugins::Status::Hash.kill()</tt>
      def tick(*messages)
        kill! if should_kill?
        set_status({'status' => STATUS_WORKING}, *messages)
      end

      # set the status to 'failed' passing along any additional messages
      def failed(*messages)
        set_status({'status' => STATUS_FAILED}, *messages)
      end

      # set the status to 'completed' passing along any addional messages
      def completed(*messages)
        set_status({
          'status' => STATUS_COMPLETED,
          'message' => "Completed at #{Time.now}"
        }, *messages)
      end

      # kill the current job, setting the status to 'killed' and raising <tt>Killed</tt>
      def kill!
        set_status({
          'status' => STATUS_KILLED,
          'message' => "Killed at #{Time.now}"
        })
        raise Killed
      end

      private
      def set_status(*args)
        self.status = [status, {'name'  => self.name}, args].flatten
      end

    end
  end
end
