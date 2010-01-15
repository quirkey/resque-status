require 'test_helper'

class TestResqueJobWithStatus < Test::Unit::TestCase
  
  context "Resque::JobWithStatus" do
    setup do
      Resque.redis.flush_all
    end
    
    context ".create" do
      setup do
        @uuid = WorkingJob.create('num' => 100)
      end
      
      should "add the job to the queue" do
        assert_equal 1, Resque.size(:statused)
      end
      
      should "set the queued object to the current class" do
        job = Resque.pop(:statused)
        assert_equal @uuid, job['args'].first
        assert_equal "WorkingJob", job['class']
      end
      
      should "add the uuid to the statuses" do
        assert_contains Resque::Status.status_ids, @uuid
      end
      
      should "return a UUID" do
        assert_match(/^\w{32}$/, @uuid)
      end
      
    end
    
    context ".enqueue" do
      setup do
        @uuid = Resque::JobWithStatus.enqueue(WorkingJob, :num => 100)
        @payload = Resque.pop(:statused)
      end
      
      should "add the job with the specific class to the queue" do
        assert_equal "WorkingJob", @payload['class']
      end
      
      should "add the arguments to the options hash" do
        assert_equal @uuid, @payload['args'].first
      end
      
      should "add the uuid to the statuses" do
        assert_contains Resque::Status.status_ids, @uuid
      end
      
      should "return UUID" do
        assert_match(/^\w{32}$/, @uuid)
      end
      
    end
    
    context ".perform" do
      setup do
        @uuid      = WorkingJob.create(:num => 100)
        @payload   = Resque.pop(:statused)
        @performed = WorkingJob.perform(*@payload['args'])
      end
      
      should "load load a new instance of the klass" do
        assert @performed.is_a?(WorkingJob)
      end
      
      should "set the uuid" do
        assert_equal @uuid, @performed.uuid
      end
      
      before_should "call perform on the inherited class" do
        WorkingJob.any_instance.expects(:perform).once
      end
      
    end
    
    context "with an invoked job" do
      setup do
        @job = WorkingJob.new('123', {'num' => 100})
      end
      
      context "#at" do
        setup do
          @job.at(50, 100, "At 50%")
        end
        
        should "calculate percent" do
          assert_equal 50, @job.status["pct_complete"]
        end
        
        should "set status" do
          assert_equal 'working', @job.status["status"]
        end
        
        should "save message" do
          assert_equal "At 50%", @job.status["message"]
        end
      end
      
      context "#failed" do
        setup do
          @job.failed("OOOOPS!")
        end
        
        should "set status" do
          assert_equal 'failed', @job.status["status"]
        end
        
        should "set message" do
          assert_equal "OOOOPS!", @job.status["message"]
        end
      end
      
      context "#completed" do
        setup do
          @job.completed
        end
        
        should "set status" do
          assert_equal 'completed', @job.status["status"]
        end
        
        should "set message" do
          assert_match(/complete/i, @job.status["message"])
        end
        
      end
      
      context "#safe_perform!" do
        setup do
          @job = ErrorJob.new("123")
          assert_raises(RuntimeError) do
            @job.safe_perform!
          end
        end
                
        should "set status as failed" do
          assert_equal 'failed', @job.status["status"]
        end
        
      end
      
    end
    
  end
  
end