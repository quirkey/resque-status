require 'test_helper'

class TestResqueStatus < Test::Unit::TestCase

  context "Resque::Status" do
    setup do
      Resque.redis.flushall
      Resque::Status.expire_in = nil
      @uuid = Resque::Status.create
      Resque::Status.set(@uuid, "my status")
      @uuid_with_json = Resque::Status.create({"im" => "json"})
    end

    context ".get" do
      should "return the status as a Resque::Status for the uuid" do
        status = Resque::Status.get(@uuid)
        assert status.is_a?(Resque::Status)
        assert_equal 'my status', status.message
      end

      should "return false if the status is not set" do
        assert !Resque::Status.get('whu')
      end

      should "decode encoded json" do
        assert_equal("json", Resque::Status.get(@uuid_with_json)['im'])
      end
    end

    context ".set" do

      should "set the status for the uuid" do
        assert Resque::Status.set(@uuid, "updated")
        assert_equal "updated", Resque::Status.get(@uuid).message
      end

      should "return the status" do
        assert Resque::Status.set(@uuid, "updated").is_a?(Resque::Status)
      end

    end

    context ".create" do
      should "add an item to a key set" do
        before = Resque::Status.status_ids.length
        Resque::Status.create
        after = Resque::Status.status_ids.length
        assert_equal 1, after - before
      end

      should "return a uuid" do
       assert_match(/^\w{32}$/, Resque::Status.create)
      end

      should "store any status passed" do
        uuid = Resque::Status.create("initial status")
        status = Resque::Status.get(uuid)
        assert status.is_a?(Resque::Status)
        assert_equal "initial status", status.message
      end

      should "expire keys if expire_in is set" do
        Resque::Status.expire_in = 1
        uuid = Resque::Status.create("new status")
        assert_contains Resque::Status.status_ids, uuid
        assert_equal "new status", Resque::Status.get(uuid).message
        sleep 2
        Resque::Status.create
        assert_does_not_contain Resque::Status.status_ids, uuid
        assert_nil Resque::Status.get(uuid)
      end

      should "store the options for the job created" do
        uuid = Resque::Status.create("new", :options => {'test' => '123'})
        assert uuid
        status = Resque::Status.get(uuid)
        assert status.is_a?(Resque::Status)
        assert_equal '123', status.options['test']
      end
    end

    context ".clear" do
      setup do
        Resque::Status.clear
      end

      should "clear any statuses" do
        assert_nil Resque::Status.get(@uuid)
      end

      should "clear any recent statuses" do
        assert Resque::Status.status_ids.empty?
      end

    end

    context ".clear_completed" do
      setup do
        @uuids = []
        15.times{ Resque::Status.create }
        15.times{ Resque::Status.create(:status => 'completed') }
        Resque::Status.clear_completed
      end

      should "clear completed statuses" do
        assert Resque::Status.status_ids.is_a?(Array)
        assert_equal 17, Resque::Status.status_ids.size # 15 + 2
      end

      should "clear any completed statuses" do
        assert Resque::Status.status_ids_with_status('completed').empty?
      end

    end

    context ".status_ids" do

      setup do
        @uuids = []
        30.times{ Resque::Status.create }
      end

      should "return an array of job ids" do
        assert Resque::Status.status_ids.is_a?(Array)
        assert_equal 32, Resque::Status.status_ids.size # 30 + 2
      end

      should "let you paginate through the statuses" do
        assert_equal Resque::Status.status_ids[0, 10], Resque::Status.status_ids(0, 9)
        assert_equal Resque::Status.status_ids[10, 10], Resque::Status.status_ids(10, 19)
        # assert_equal Resque::Status.status_ids.reverse[0, 10], Resque::Status.status_ids(0, 10)
      end
    end

    context ".status_ids_with_status" do

      setup do
        @uuids = []
        15.times{ Resque::Status.create }
        15.times{ Resque::Status.create(:status => 'completed') }
      end

      should "return an array of completed job ids" do
        assert Resque::Status.status_ids_with_status('completed').is_a?(Array)
        assert_equal 15, Resque::Status.status_ids_with_status('completed').size # 15
      end
    end

    context ".statuses" do

      should "return an array status objects" do
        statuses = Resque::Status.statuses
        assert statuses.is_a?(Array)
        assert_same_elements [@uuid_with_json, @uuid], statuses.collect {|s| s.uuid }
      end

    end

    # context ".count" do
    #
    #   should "return a count of statuses" do
    #     statuses = Resque::Status.statuses
    #     assert_equal 2, statuses.size
    #     assert_equal statuses.size, Resque::Status.count
    #   end
    #
    # end

    context ".logger" do
      setup do
        @logger = Resque::Status.logger(@uuid)
      end

      should "return a redisk logger" do
        assert @logger.is_a?(Redisk::Logger)
      end

      should "scope the logger to a key" do
        assert_match(/#{@uuid}/, @logger.name)
      end

    end

  end

end
