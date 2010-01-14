require 'test_helper'

class TestResqueStatusChore < Test::Unit::TestCase
  
  context "Resque::Status::Chore" do
    
    context ".create" do
      
      should "add the job to the queue" do
        
      end
      
      should "set the queued object to the current class" do
        
      end
      
      should "add the uuid to the statuses" do
        
      end
      
      should "return a UUID" do
        
      end
      
    end
    
    context ".enqueue" do
      
      should "add the job with the specific class to the queue" do
        
      end
      
      should "add the arguments to the options hash" do
        
      end
      
      should "return UUID" do
        
      end
      
    end
    
    context ".perform" do
      
      should "load load a new instance of the klass" do
        
      end
      
      should "set the uuid" do
        
      end
      
      should "call run on the inherited class" do
        
      end
      
    end
    
    context "with an invoked chore" do
      
      context "#at" do
        should "calculate percent" do
          
        end
        
        should "save message" do
          
        end
      end
      
      context "#failed" do
        
        should "set status" do
          
        end
        
        should "set message" do
          
        end
      end
      
      context "#completed" do
        
        should "set status" do
          
        end
        
        should "set message" do
          
        end
        
      end
      
      context "#safe_run!" do
        
        should "re-raise errors" do
          
        end
        
        should "set status as failed" do
          
        end
        
      end
      
    end
    
  end
  
end