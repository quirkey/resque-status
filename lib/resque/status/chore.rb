module Resque
  module Status
    class Chore
      
      attr_reader :uuid, :options

      def self.perform_with_job(job, *args)
        options = args.shift || {}
        new(job, options, *args).safe_run
      end

      def initialize(job, options, *args)
        self.job     = job
        self.options = options
        self.args    = args
      end

      def safe_run
        run!
      rescue => e
        logger.error e
        failed("The task failed because of an error: #{e.inspect}")
        raise e
      end

      def logger
        @logger ||= Resque::Status.logger(uuid)
      end

      def at(num, total, message)
        total = (total == 0 || total.nil?) ? 1 : total
        pct = (((num || 0).to_f / total.to_f) * 100).to_i
        set_status({
          'pct_complete' => pct, 
          'num' => num, 
          'total' => total, 
          'status' => 'working',
          'message' => message
        })
      end

      def failed(message)
        set_status({
          'pct_complete' => 100,
          'status' => 'failed',
          'message' => message
        })
      end

      def completed(message = nil)
        set_status({
          'pct_complete' => 100, 
          'status' => 'completed',
          'message' => message || "Completed at #{Time.now}"
        })
      end

      def set_status(status = {})
        job.status = {
          'time' => Time.now.to_i,
          'name'  => self.class.name,
          'status' => 'queued'
        }.merge(status)
      end
      
    end
  end
end