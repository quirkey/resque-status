module Resque
  module Plugins
    module Status
      class Job
        include Resque::Plugins::Status
        
        def perform_or_raise(obj)
          begin
            # execute the block given
            yield
            
            # if it completed successfully, mark the object successful
            obj.successful! if obj.respond_to?(:successful!)
          rescue => e
            failed_failed = false
            
            begin
              obj.failed! if obj.respond_to?(:failed!)
            rescue
              failed_failed = true
            end
            
            # TODO: Add NewRelic hook
            
            # don't return raw database errors except in development
            if e.is_a? MySQL2::Error && Rails.env != :development
              failed "Database error"
            else
              failed e.to_s
            end
            
            raise e if Rails.env == :development
          end
        end
        
      end
    end
  end
end