module Resque
  module Plugins
    module Status
      module HasJob
        def uuid
          "#{self.class.name.underscore.gsub("/","::")}:#{self.id}"
        end

        def job
          Resque::Plugins::Status::Hash.get self.uuid
        end
  
        def job_active?
          self.job && !self.job.terminal?
        end

        def job_class
          (self.class.name + "Job").camelcase.constantize
        end

        def run_job!
          job_class.create id: self.id, uuid: self.uuid
        end
  
        def default_error_message
          "An error occurred.  Please check your selections and try again."
        end
  
        def failure_message
          if self.job
            self.job.message
          else
            self.default_error_message
          end
        end
        
      end
      
      #----------
      
      module HasJobWithState

        def add_states *names
          @states ||= []

          names.each do |name|
            define_method("#{name}?") { state.to_sym == name.to_sym   }
            define_method("#{name}!") { update_attributes state: name }
            @states << name.to_sym
          end
        end

        def states; @states; end

        def self.extended base
          base.send :include, Resque::Plugins::Status::HasJob
          base.add_states :new, :failed, :successful
        end
        
      end
    end
  end
end
