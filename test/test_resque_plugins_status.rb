require 'test_helper'

class TestResquePluginsStatus < Test::Unit::TestCase

  context "Resque::Plugins::Status" do
    setup do
      Resque.redis.flushall
    end

    context ".create" do
      context "not inline" do
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
          assert_contains Resque::Plugins::Status::Hash.status_ids, @uuid
        end

        should "return a UUID" do
          assert_match(/^\w{32}$/, @uuid)
        end
      end

      context "inline" do
        setup do
          Resque.stubs(:inline?).returns(true)
        end

        should "not queue a job" do
          @uuid = WorkingJob.create('num' => 100)
          assert_equal 0, Resque.size(:statused)
        end

        should "call perform" do
          WorkingJob.any_instance.expects(:perform).once
          @uuid = WorkingJob.create('num' => 100)
        end
      end
    end

    context ".create with a failing before_enqueue hook" do
      setup do
        @size = Resque.size(:statused)
        @status_ids_size = Resque::Plugins::Status::Hash.status_ids.length
        @res = NeverQueuedJob.create(:num => 100)
      end

      should "return nil" do
        assert_equal nil, @res
      end

      should "not create a status" do
        assert_equal @size, Resque.size(:statused)
      end

      should "not add the uuid to the statuses" do
        assert_equal @status_ids_size, Resque::Plugins::Status::Hash.status_ids.length
      end
    end

    context ".scheduled" do
      setup do
        @job_args = {'num' => 100}
        @uuid = WorkingJob.scheduled(:queue_name, WorkingJob, @job_args)
      end

      should "create the job with the provided arguments" do
        job = Resque.pop(:queue_name)
        assert_equal @job_args, job['args'].last
      end
    end

    context ".enqueue" do
      should "delegate to enqueue_to, filling in the queue from the class" do
        @uuid = BasicJob.enqueue(WorkingJob, :num => 100)
        @payload = Resque.pop(:statused)
        assert_equal "WorkingJob", @payload['class']
      end
    end

    context ".enqueue_to" do
      setup do
        @uuid = BasicJob.enqueue_to(:new_queue, WorkingJob, :num => 100)
        @payload = Resque.pop(:new_queue)
      end

      should "add the job with the specific class to the queue" do
        assert_equal "WorkingJob", @payload['class']
      end

      should "add the arguments to the options hash" do
        assert_equal @uuid, @payload['args'].first
      end

      should "add the uuid to the statuses" do
        assert_contains Resque::Plugins::Status::Hash.status_ids, @uuid
      end

      should "return UUID" do
        assert_match(/^\w{32}$/, @uuid)
      end

    end

    context ".dequeue" do
      setup do
        @uuid1 = BasicJob.enqueue(WorkingJob, :num => 100)
        @uuid2 = BasicJob.enqueue(WorkingJob, :num => 100)
      end

      should "dequeue the job with the uuid from the correct queue" do
        size = Resque.size(:statused)
        BasicJob.dequeue(WorkingJob, @uuid2)
        assert_equal size-1, Resque.size(:statused)
      end
      should "not dequeue any jobs with different uuids for same class name" do
        BasicJob.dequeue(WorkingJob, @uuid2)
        assert_equal @uuid1, Resque.pop(:statused)['args'].first
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

      should "set the status" do
        assert @performed.status.is_a?(Resque::Plugins::Status::Hash)
        assert_equal 'WorkingJob({"num"=>100})', @performed.status.name
      end

      before_should "call perform on the inherited class" do
        WorkingJob.any_instance.expects(:perform).once
      end
    end

    context "manually failing a job" do
      setup do
        @uuid      = FailureJob.create(:num => 100)
        @payload   = Resque.pop(:statused)
        @performed = FailureJob.perform(*@payload['args'])
      end

      should "load load a new instance of the klass" do
        assert @performed.is_a?(FailureJob)
      end

      should "set the uuid" do
        assert_equal @uuid, @performed.uuid
      end

      should "set the status" do
        assert @performed.status.is_a?(Resque::Plugins::Status::Hash)
        assert_equal 'FailureJob({"num"=>100})', @performed.status.name
      end

      should "be failed" do
        assert_match(/failure/, @performed.status.message)
        assert @performed.status.failed?
      end

    end

    context "killing a job" do
      setup do
        @uuid      = KillableJob.create(:num => 100)
        @payload   = Resque.pop(:statused)
        Resque::Plugins::Status::Hash.kill(@uuid)
        assert_contains Resque::Plugins::Status::Hash.kill_ids, @uuid
        @performed = KillableJob.perform(*@payload['args'])
        @status = Resque::Plugins::Status::Hash.get(@uuid)
      end

      should "set the status to killed" do
        assert @status.killed?
        assert !@status.completed?
      end

      should "only perform iterations up to kill" do
        assert_equal 1, Resque.redis.get("#{@uuid}:iterations").to_i
      end

      should "not persist the kill key" do
        assert_does_not_contain Resque::Plugins::Status::Hash.kill_ids, @uuid
      end
    end

    context "killing all jobs" do
      setup do
        @uuid1    = KillableJob.create(:num => 100)
        @uuid2    = KillableJob.create(:num => 100)

        Resque::Plugins::Status::Hash.killall

        assert_contains Resque::Plugins::Status::Hash.kill_ids, @uuid1
        assert_contains Resque::Plugins::Status::Hash.kill_ids, @uuid2

        @payload1   = Resque.pop(:statused)
        @payload2   = Resque.pop(:statused)

        @performed = KillableJob.perform(*@payload1['args'])
        @performed = KillableJob.perform(*@payload2['args'])

        @status1, @status2 = Resque::Plugins::Status::Hash.mget([@uuid1, @uuid2])
      end

      should "set the status to killed" do
        assert @status1.killed?
        assert !@status1.completed?
        assert @status2.killed?
        assert !@status2.completed?
      end

      should "only perform iterations up to kill" do
        assert_equal 1, Resque.redis.get("#{@uuid1}:iterations").to_i
        assert_equal 1, Resque.redis.get("#{@uuid2}:iterations").to_i
      end

      should "not persist the kill key" do
        assert_does_not_contain Resque::Plugins::Status::Hash.kill_ids, @uuid1
        assert_does_not_contain Resque::Plugins::Status::Hash.kill_ids, @uuid2
      end

    end

    context "invoking killall jobs to kill a range" do
      setup do
        @uuid1    = KillableJob.create(:num => 100)
        @uuid2    = KillableJob.create(:num => 100)

        Resque::Plugins::Status::Hash.killall(0,0) # only @uuid2 should be killed

        assert_does_not_contain Resque::Plugins::Status::Hash.kill_ids, @uuid1
        assert_contains Resque::Plugins::Status::Hash.kill_ids, @uuid2

        @payload1   = Resque.pop(:statused)
        @payload2   = Resque.pop(:statused)

        @performed = KillableJob.perform(*@payload1['args'])
        @performed = KillableJob.perform(*@payload2['args'])

        @status1, @status2 = Resque::Plugins::Status::Hash.mget([@uuid1, @uuid2])
      end

      should "set the status to killed" do
        assert !@status1.killed?
        assert @status1.completed?
        assert @status2.killed?
        assert !@status2.completed?
      end

      should "only perform iterations up to kill" do
        assert_equal 100, Resque.redis.get("#{@uuid1}:iterations").to_i
        assert_equal 1, Resque.redis.get("#{@uuid2}:iterations").to_i
      end

      should "not persist the kill key" do
        assert_does_not_contain Resque::Plugins::Status::Hash.kill_ids, @uuid1
        assert_does_not_contain Resque::Plugins::Status::Hash.kill_ids, @uuid2
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
          assert_equal 50, @job.status.pct_complete
        end

        should "set status" do
          assert @job.status.working?
        end

        should "save message" do
          assert_equal "At 50%", @job.status.message
        end
      end

      context "#failed" do
        setup do
          @job.failed("OOOOPS!")
        end

        should "set status" do
          assert @job.status.failed?
        end

        should "set message" do
          assert_equal "OOOOPS!", @job.status.message
        end
      end

      context "#completed" do
        setup do
          @job.completed
        end

        should "set status" do
          assert @job.status.completed?
        end

        should "set message" do
          assert_match(/complete/i, @job.status.message)
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
          assert @job.status.failed?
        end
      end

    end

  end

end
