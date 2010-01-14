require 'test_helper'

class TestResqueStatus < Test::Unit::TestCase

  context "Resque::Status" do
    setup do
      Resque.redis.flush_all
      @uuid = Resque::Status.create
      Resque::Status.set(@uuid, "my status")
      @uuid_with_json = Resque::Status.create({"im" => "json"})
    end
    
    context ".get" do 
      should "return the status as a string for the uuid" do
        assert_equal 'my status', Resque::Status.get(@uuid)
      end
      
      should "return false if the status is not set" do
        assert !Resque::Status.get('whu')
      end
      
      should "decode encoded json" do
        assert_equal({"im" => "json"}, Resque::Status.get(@uuid_with_json))
      end
    end
    
    context ".set" do
        
      should "set the status for the uuid" do
        assert Resque::Status.set(@uuid, "updated")
        assert_equal "updated", Resque::Status.get(@uuid)
      end
      
      should "return the status" do
        assert_equal "updated", Resque::Status.set(@uuid, "updated")
      end
      
      should "encode objects as json" do
        assert "{\"1\":\"2\"}", Resque::Status.set(@uuid, {"1" => "2"})
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
        assert_equal "initial status", Resque::Status.get(uuid)
      end
    end
    
    context ".status_ids" do
      should "return an array of job ids" do
        assert Resque::Status.status_ids.is_a?(Array)
      end
    end
    
    context ".statuses" do
      
      should "return a hash of ids and status objects" do
        statuses = Resque::Status.statuses
        assert statuses.is_a?(Hash)
        assert_same_elements [@uuid_with_json, @uuid], statuses.keys
      end
      
    end
    
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
