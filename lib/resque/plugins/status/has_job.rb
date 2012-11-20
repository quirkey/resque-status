module Resque
  module Plugins
    module Status
      module HasJob
        def uuid
          "#{self.class.name.underscore}/#{self.id}"
        end

        def job
          Resque::Plugins::Status::Hash.get self.uuid
        end
  
        def job_active?
          if self.job && !self.job.terminal?
            true
          else
            false
          end
        end

        def job_class
          (self.class.name + "Job").camelcase.constantize
        end

        def run_job!
          job_class.create :id => self.id, 
            :uuid     => self.uuid
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
        # -- functions dealing with model.state -- #
  
        def new?
          self.state == 'new'
        end
  
        def failed?
          self.state == 'failed'
        end
        
        def successful?
          self.state == 'successful'
        end
  
        def failed!
          self.update_attributes :state => 'failed'
        end
  
        def successful!
          self.update_attributes :state => 'successful'    
        end
        
      end
    end
  end
end