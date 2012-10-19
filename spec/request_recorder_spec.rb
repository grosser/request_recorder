require "spec_helper"

describe RequestRecorder do
  let(:original_logger){ ActiveSupport::BufferedLogger.new("/dev/null") }
  let(:activate_logger){ {"QUERY_STRING" => "__request_recording=10"} }
  let(:inner_app){ lambda{|env|
    Car.first
    [200, {}, "assadasd"]
  } }
  let(:middleware){ RequestRecorder::Middleware.new(inner_app, :store => RequestRecorder::RedisLogger.new(redis)) }
  let(:redis){ FakeRedis::Redis.new }
  let(:redis_key){ RequestRecorder::RedisLogger::KEY }
  let(:existing_request_id){ redis.hset(redis_key, "123456789", "BEFORE") ; "123456789"}

  before do
    ActiveRecord::Base.logger.instance_variable_set("@log", original_logger)
    ActiveRecord::Base.logger.auto_flushing = 1000
    ActiveRecord::Base.logger.level = Logger::ERROR
  end

  after do
    redis.flushall
  end

  it "has a VERSION" do
    RequestRecorder::VERSION.should =~ /^[\.\da-z]+$/
  end

  it "records activerecord queries" do
    middleware.call(activate_logger)
    stored.values.last.should include "SELECT"
  end

  it "blows up if you go over the maximum" do
    status, headers, body = middleware.call("QUERY_STRING" => "__request_recording=99999")
    status.should == 500
    body.should include "maximum"
  end

  context "subsequent requests" do
    it "sets cookie in first step" do
      status, headers, body = middleware.call(activate_logger)
      generated_id = stored.keys.last
      headers["Set-Cookie"].should include "__request_recording=9%3A#{generated_id}; expires="
      headers["Set-Cookie"].should include "; HttpOnly"
    end

    it "appends to existing log" do
      middleware.call("HTTP_COOKIE" => "__request_recording=8:#{existing_request_id}")
      existing_request = redis.hget(redis_key, existing_request_id)
      existing_request.should include "SELECT"
      existing_request.should include "BEFORE"
    end

    it "creates a new log if redis dies" do
      existing_request_id # store key
      redis.flushall
      middleware.call("HTTP_COOKIE" => "__request_recording=8:#{existing_request_id}")
      existing_request = redis.hget(redis_key, existing_request_id)
      existing_request.should include "SELECT"
      existing_request.should_not include "BEFORE"
    end

    it "decrements cookie on each step" do
      status, headers, body = middleware.call("HTTP_COOKIE" => "__request_recording=2:#{existing_request_id};foo=bar")
      headers["Set-Cookie"].should include "__request_recording=1%3A#{existing_request_id}; expires="
    end

    it "removes cookie if final step is reached" do
      status, headers, body = middleware.call("HTTP_COOKIE" => "__request_recording=1:#{existing_request_id};foo=bar")
      headers["Set-Cookie"].should include "__request_recording=; expires="
    end
  end

  it "should not record if __request_recording is not given" do
    middleware.call(
      "QUERY_STRING" => "stuff=hello", "HTTP_COOKIE" => "bar=foo"
    )
    stored.count.should == 0
  end

  it "restores the AR logger after executing" do
    middleware.call(activate_logger)

    ActiveRecord::Base.logger.instance_variable_get("@log").object_id.should == original_logger.object_id
    ActiveRecord::Base.logger.auto_flushing.should == 1000
    ActiveRecord::Base.logger.level.should == Logger::ERROR
  end

  it "fails with a nice message if logging_to_recorded blows up" do
    StringIO.should_receive(:new).and_raise("Oooops")
    expect{
      middleware.call(activate_logger)
    }.to raise_error "Oooops"
  end

  private

  def stored
    redis.hgetall(redis_key)
  end
end
