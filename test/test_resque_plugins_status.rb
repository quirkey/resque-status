require 'test_helper'

class TestResquePluginsStatus < Minitest::Test

  describe "Resque::Plugins::Status" do
    before do
      Resque.redis.flushall
    end

    describe ".create" do
      describe "not inline" do
        before do
          @uuid = WorkingJob.create('num' => 100)
        end

        it "add the job to the queue" do
          assert_equal 1, Resque.size(:statused)
        end

        it "set the queued object to the current class" do
          job = Resque.pop(:statused)
          assert_equal @uuid, job['args'].first
          assert_equal "WorkingJob", job['class']
        end

        it "add the uuid to the statuses" do
          assert_includes Resque::Plugins::Status::Hash.status_ids, @uuid
        end

        it "return a UUID" do
          assert_match(/^\w{32}$/, @uuid)
        end
      end

      describe "inline" do
        before do
          Resque.stubs(:inline?).returns(true)
        end

        it "not queue a job" do
          @uuid = WorkingJob.create('num' => 100)
          assert_equal 0, Resque.size(:statused)
        end

        it "call perform" do
          WorkingJob.any_instance.expects(:perform).once
          @uuid = WorkingJob.create('num' => 100)
        end
      end
    end

    describe ".create with a failing before_enqueue hook" do
      before do
        @size = Resque.size(:statused)
        @status_ids_size = Resque::Plugins::Status::Hash.status_ids.length
        @res = NeverQueuedJob.create(:num => 100)
      end

      it "return nil" do
        assert_equal nil, @res
      end

      it "not create a status" do
        assert_equal @size, Resque.size(:statused)
      end

      it "not add the uuid to the statuses" do
        assert_equal @status_ids_size, Resque::Plugins::Status::Hash.status_ids.length
      end
    end

    describe ".scheduled" do
      before do
        @job_args = {'num' => 100}
        @uuid = WorkingJob.scheduled(:queue_name, WorkingJob, @job_args)
      end

      it "create the job with the provided arguments" do
        job = Resque.pop(:queue_name)
        assert_equal @job_args, job['args'].last
      end
    end

    describe ".enqueue" do
      it "delegate to enqueue_to, filling in the queue from the class" do
        @uuid = BasicJob.enqueue(WorkingJob, :num => 100)
        @payload = Resque.pop(:statused)
        assert_equal "WorkingJob", @payload['class']
      end
    end

    describe ".enqueue_to" do
      before do
        @uuid = BasicJob.enqueue_to(:new_queue, WorkingJob, :num => 100)
        @payload = Resque.pop(:new_queue)
      end

      it "add the job with the specific class to the queue" do
        assert_equal "WorkingJob", @payload['class']
      end

      it "add the arguments to the options hash" do
        assert_equal @uuid, @payload['args'].first
      end

      it "add the uuid to the statuses" do
        assert_includes Resque::Plugins::Status::Hash.status_ids, @uuid
      end

      it "return UUID" do
        assert_match(/^\w{32}$/, @uuid)
      end

    end

    describe ".dequeue" do
      before do
        @uuid1 = BasicJob.enqueue(WorkingJob, :num => 100)
        @uuid2 = BasicJob.enqueue(WorkingJob, :num => 100)
      end

      it "dequeue the job with the uuid from the correct queue" do
        size = Resque.size(:statused)
        BasicJob.dequeue(WorkingJob, @uuid2)
        assert_equal size-1, Resque.size(:statused)
      end
      it "not dequeue any jobs with different uuids for same class name" do
        BasicJob.dequeue(WorkingJob, @uuid2)
        assert_equal @uuid1, Resque.pop(:statused)['args'].first
      end
    end

    describe ".perform" do
      let(:expectation) { }

      before do
        expectation
        @uuid      = WorkingJob.create(:num => 100)
        @payload   = Resque.pop(:statused)
        @performed = WorkingJob.perform(*@payload['args'])
      end

      it "load load a new instance of the klass" do
        assert @performed.is_a?(WorkingJob)
      end

      it "set the uuid" do
        assert_equal @uuid, @performed.uuid
      end

      it "set the status" do
        assert @performed.status.is_a?(Resque::Plugins::Status::Hash)
        assert_equal 'WorkingJob({"num"=>100})', @performed.status.name
      end

      describe "before" do
        let(:expectation) { WorkingJob.any_instance.expects(:perform).once }
        it("call perform on the inherited class") {}
      end
    end

    describe "manually failing a job" do
      before do
        @uuid      = FailureJob.create(:num => 100)
        @payload   = Resque.pop(:statused)
        @performed = FailureJob.perform(*@payload['args'])
      end

      it "load load a new instance of the klass" do
        assert @performed.is_a?(FailureJob)
      end

      it "set the uuid" do
        assert_equal @uuid, @performed.uuid
      end

      it "set the status" do
        assert @performed.status.is_a?(Resque::Plugins::Status::Hash)
        assert_equal 'FailureJob({"num"=>100})', @performed.status.name
      end

      it "be failed" do
        assert_match(/failure/, @performed.status.message)
        assert @performed.status.failed?
      end

    end

    describe "killing a job" do
      before do
        @uuid      = KillableJob.create(:num => 100)
        @payload   = Resque.pop(:statused)
        Resque::Plugins::Status::Hash.kill(@uuid)
        assert_includes Resque::Plugins::Status::Hash.kill_ids, @uuid
        @performed = KillableJob.perform(*@payload['args'])
        @status = Resque::Plugins::Status::Hash.get(@uuid)
      end

      it "set the status to killed" do
        assert @status.killed?
        assert !@status.completed?
      end

      it "only perform iterations up to kill" do
        assert_equal 1, Resque.redis.get("#{@uuid}:iterations").to_i
      end

      it "not persist the kill key" do
        refute_includes Resque::Plugins::Status::Hash.kill_ids, @uuid
      end
    end

    describe "killing all jobs" do
      before do
        @uuid1    = KillableJob.create(:num => 100)
        @uuid2    = KillableJob.create(:num => 100)

        Resque::Plugins::Status::Hash.killall

        assert_includes Resque::Plugins::Status::Hash.kill_ids, @uuid1
        assert_includes Resque::Plugins::Status::Hash.kill_ids, @uuid2

        @payload1   = Resque.pop(:statused)
        @payload2   = Resque.pop(:statused)

        @performed = KillableJob.perform(*@payload1['args'])
        @performed = KillableJob.perform(*@payload2['args'])

        @status1, @status2 = Resque::Plugins::Status::Hash.mget([@uuid1, @uuid2])
      end

      it "set the status to killed" do
        assert @status1.killed?
        assert !@status1.completed?
        assert @status2.killed?
        assert !@status2.completed?
      end

      it "only perform iterations up to kill" do
        assert_equal 1, Resque.redis.get("#{@uuid1}:iterations").to_i
        assert_equal 1, Resque.redis.get("#{@uuid2}:iterations").to_i
      end

      it "not persist the kill key" do
        refute_includes Resque::Plugins::Status::Hash.kill_ids, @uuid1
        refute_includes Resque::Plugins::Status::Hash.kill_ids, @uuid2
      end

    end

    describe "invoking killall jobs to kill a range" do
      before do
        Timecop.travel(-1) do
          @uuid1 = KillableJob.create(:num => 100)
        end
        @uuid2 = KillableJob.create(:num => 100)

        Resque::Plugins::Status::Hash.killall(0,0) # only @uuid2 it be killed

        refute_includes Resque::Plugins::Status::Hash.kill_ids, @uuid1
        assert_includes Resque::Plugins::Status::Hash.kill_ids, @uuid2

        @payload1   = Resque.pop(:statused)
        @payload2   = Resque.pop(:statused)

        @performed = KillableJob.perform(*@payload1['args'])
        @performed = KillableJob.perform(*@payload2['args'])

        @status1, @status2 = Resque::Plugins::Status::Hash.mget([@uuid1, @uuid2])
      end

      it "set the status to killed" do
        assert !@status1.killed?
        assert @status1.completed?
        assert @status2.killed?
        assert !@status2.completed?
      end

      it "only perform iterations up to kill" do
        assert_equal 100, Resque.redis.get("#{@uuid1}:iterations").to_i
        assert_equal 1, Resque.redis.get("#{@uuid2}:iterations").to_i
      end

      it "not persist the kill key" do
        refute_includes Resque::Plugins::Status::Hash.kill_ids, @uuid1
        refute_includes Resque::Plugins::Status::Hash.kill_ids, @uuid2
      end

    end

    describe "with an invoked job" do
      before do
        @job = WorkingJob.new('123', {'num' => 100})
      end

      describe "#at" do
        before do
          @job.at(50, 100, "At 50%")
        end

        it "calculate percent" do
          assert_equal 50, @job.status.pct_complete
        end

        it "set status" do
          assert @job.status.working?
        end

        it "save message" do
          assert_equal "At 50%", @job.status.message
        end
      end

      describe "#failed" do
        before do
          @job.failed("OOOOPS!")
        end

        it "set status" do
          assert @job.status.failed?
        end

        it "set message" do
          assert_equal "OOOOPS!", @job.status.message
        end
      end

      describe "#completed" do
        before do
          @job.completed
        end

        it "set status" do
          assert @job.status.completed?
        end

        it "set message" do
          assert_match(/complete/i, @job.status.message)
        end

      end

      describe "#safe_perform!" do
        before do
          @job = ErrorJob.new("123")
          assert_raises(RuntimeError) do
            @job.safe_perform!
          end
        end

        it "set status as failed" do
          assert @job.status.failed?
        end
      end

    end

  end

end
