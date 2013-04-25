require "spec_helper"

describe RequestRecorder do
  class FooError < RuntimeError;end

  let(:activate_logger){{ "QUERY_STRING" => "request_recorder=10" }}
  let(:middleware) { RequestRecorder::Middleware.new(inner_app, :store => RequestRecorder::RedisLogger.new(redis)) }
  let(:inner_app) do
    lambda do |env|
      Car.first

      (env["log"] || []).each { |line| ActiveRecord::Base.logger.info(line) }

      if env["raise"]
        # rails also logs errors
        ActiveRecord::Base.logger.error(env["raise"])
        raise FooError.new(env["raise"])
      end
      [200, {}, "assadasd"]
    end
  end
  let(:redis){ FakeRedis::Redis.new }
  let(:redis_key){ RequestRecorder::RedisLogger::KEY }
  let(:existing_request_id){ redis.hset(redis_key, "123_456", "BEFORE") ; "123_456"}

  before do
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

  it "records exceptions" do
    begin
      middleware.call(activate_logger.merge("raise" => "FooBarError"))
      fail
    rescue FooError
    end
    stored.values.last.should include "FooBarError"
  end

  it "starts with a given key" do
    middleware.call({"QUERY_STRING" => "request_recorder=10-abcdefg"})
    redis.hget(redis_key, "abcdefg").should include "SELECT"
  end

  it "blows up if you go over the maximum" do
    status, headers, body = middleware.call("QUERY_STRING" => "request_recorder=99999")
    status.should == 500
    body.should include "maximum"
  end

  context "subsequent requests" do
    it "sets cookie in first step" do
      status, headers, body = middleware.call(activate_logger)
      generated_id = stored.keys.last
      headers["Set-Cookie"].should include "request_recorder=9-#{generated_id.gsub(":", "%3A").gsub(" ", "+")}; expires="
      headers["Set-Cookie"].should include "; HttpOnly"
    end

    it "appends to existing log" do
      middleware.call("HTTP_COOKIE" => "request_recorder=8-#{existing_request_id}")
      existing_request = redis.hget(redis_key, existing_request_id)
      existing_request.should include "SELECT"
      existing_request.should include "BEFORE"
    end

    it "creates a new log if redis dies" do
      existing_request_id # store key
      redis.flushall
      middleware.call("HTTP_COOKIE" => "request_recorder=8-#{existing_request_id}")
      existing_request = redis.hget(redis_key, existing_request_id)
      existing_request.should include "SELECT"
      existing_request.should_not include "BEFORE"
    end

    it "decrements cookie on each step" do
      status, headers, body = middleware.call("HTTP_COOKIE" => "request_recorder=2-#{existing_request_id};foo=bar")
      headers["Set-Cookie"].sub(" max-age=0;", "").should include "request_recorder=1-#{existing_request_id}; expires="
    end

    it "removes cookie if final step is reached" do
      status, headers, body = middleware.call("HTTP_COOKIE" => "request_recorder=1-#{existing_request_id};foo=bar")
      headers["Set-Cookie"].sub(" max-age=0;", "").should include "request_recorder=; expires="
    end
  end

  it "should not record if request_recorder is not given" do
    middleware.call(
      "QUERY_STRING" => "stuff=hello", "HTTP_COOKIE" => "bar=foo"
    )
    stored.count.should == 0
  end

  it "restores the AR logger after executing" do
    middleware.call(activate_logger)
    ActiveRecord::Base.logger.level.should == Logger::ERROR
  end

  it "fails with a nice message if logging_to_recorded blows up" do
    StringIO.should_receive(:new).and_raise("Oooops")
    expect{
      middleware.call(activate_logger)
    }.to raise_error "Oooops"
  end

  context "frontend" do
    let(:store){ RequestRecorder::RedisLogger.new(redis) }
    let(:middleware){
      RequestRecorder::Middleware.new(
        inner_app,
        :store => store,
        :frontend_auth => lambda{|env| env["success"] },
        :headers => {:max => 1000}
      )
    }

    before do
      store.write("xxx", "yyy")
    end

    it "can view a log" do
      status, headers, body = middleware.call("PATH_INFO" => "/request_recorder/xxx", "success" => true)
      status.should == 200
      body.should include("yyy")
    end

    it "cannot view a log if auth fails" do
      status, headers, body = middleware.call("PATH_INFO" => "/request_recorder/xxx")
      status.should == 401
      body.should_not include("yyy")
    end

    it "cannot view a missing log" do
      status, headers, body = middleware.call("PATH_INFO" => "/request_recorder/missing-key", "success" => true)
      status.should == 404
      body.should include("missing-key")
    end

    it "warns about unconfigured :frontend_auth" do
      middleware = RequestRecorder::Middleware.new(inner_app, :store => store, :max_header_size => 1000)
      status, headers, body = middleware.call("PATH_INFO" => "/request_recorder/xxx")
      status.should == 500
      body.should include(":frontend_auth")
    end

    context "chrome logger" do
      def decode(headers)
        MultiJson.load(Base64.decode64(headers["X-ChromeLogger-Data"]))
      end

      it "logs into chrome logger" do
        status, headers, body = middleware.call("QUERY_STRING" => "request_recorder=10-xxx", "success" => true)
        headers["X-ChromeLogger-Data"].should_not == nil
        data = decode(headers)
        data["rows"][1][0][2..-1] = "---" # remove timing information + activerecord 2/3 diff
        data.should == {
          "version"=>"0.1.1",
          "columns"=>["log", "backtrace", "type"],
          "rows"=>[
            [["Rails log request_recorder=10-xxx"], "xxx.rb:1", "group"],
            [["Car", "Load", "---"], "xxx.rb:1", ""],
            [[], "xxx.rb:1", "groupEnd"]
          ]
        }
      end

      it "does not log without frontend_auth" do
        status, headers, body = middleware.call("QUERY_STRING" => "request_recorder=10-xxx")
        headers["X-ChromeLogger-Data"].should == nil
      end
    end
  end

  it "integrates" do
    stored.size.should == 0

    # request 1 - start + decrement + log
    status, headers, body = middleware.call({"QUERY_STRING" => "request_recorder=3-foo"})
    stored.size.should == 1
    stored.values.last.scan("SELECT").size.should == 1
    cookie = headers["Set-Cookie"].split(";").first

    # request 2 - decrement + log
    status, headers, body = middleware.call({"HTTP_COOKIE" => cookie})
    stored.size.should == 1
    stored.values.last.scan("SELECT").size.should == 2
    cookie = headers["Set-Cookie"].split(";").first

    # request 3 - remove cookie + log
    status, headers, body = middleware.call({"HTTP_COOKIE" => cookie})
    stored.size.should == 1
    stored.values.last.scan("SELECT").size.should == 3
    cookie = headers["Set-Cookie"].split(";").first
    cookie.should == "request_recorder="

    # request 4 - no more logging
    status, headers, body = middleware.call({})
    stored.size.should == 1
    stored.values.last.scan("SELECT").size.should == 3
  end

  private

  def stored
    redis.hgetall(redis_key)
  end
end
