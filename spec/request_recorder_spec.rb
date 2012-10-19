require "spec_helper"

describe RequestRecorder do
  let(:original_logger){ ActiveSupport::BufferedLogger.new("/dev/null") }
  let(:activate_logger){ {"QUERY_STRING" => "__request_recording=10"} }
  let(:inner_app){ lambda{|env|
    Car.first
    [200, {}, "assadasd"]
  } }
  let(:existing_request){ RequestRecorder::Request.create(:log => "BEFORE") }

  before do
    ActiveRecord::Base.logger.instance_variable_set("@log", original_logger)
    ActiveRecord::Base.logger.auto_flushing = 1000
    ActiveRecord::Base.logger.level = Logger::ERROR
  end

  after do
    RequestRecorder::Request.delete_all
  end

  it "has a VERSION" do
    RequestRecorder::VERSION.should =~ /^[\.\da-z]+$/
  end

  it "records activerecord queries" do
    middleware = RequestRecorder::Middleware.new(inner_app)
    middleware.call(activate_logger)
    RequestRecorder::Request.last.log.should include "SELECT"
  end

  it "blows up if you go over the maximum" do
    middleware = RequestRecorder::Middleware.new(inner_app)
    status, headers, body = middleware.call("QUERY_STRING" => "__request_recording=99999")
    status.should == 500
    body.should include "maximum"
  end

  context "subsequent requests" do
    it "sets cookie in first step" do
      middleware = RequestRecorder::Middleware.new(inner_app)
      status, headers, body = middleware.call(activate_logger)
      generated = RequestRecorder::Request.last
      headers["Set-Cookie"].should include "__request_recording=9%3A#{generated.id}; path=/; expires="
    end

    it "appends to existing log" do
      middleware = RequestRecorder::Middleware.new(inner_app)
      middleware.call("HTTP_COOKIE" => "__request_recording=8:#{existing_request.id}")
      existing_request.reload
      existing_request.log.should include "SELECT"
      existing_request.log.should include "BEFORE"
    end

    it "decrements cookie on each step" do
      middleware = RequestRecorder::Middleware.new(inner_app)
      status, headers, body = middleware.call("HTTP_COOKIE" => "__request_recording=2:#{existing_request.id};foo=bar")
      headers["Set-Cookie"].should include "__request_recording=1%3A#{existing_request.id}; path=/; expires="
    end

    it "removes cookie if final step is reached" do
      middleware = RequestRecorder::Middleware.new(inner_app)
      status, headers, body = middleware.call("HTTP_COOKIE" => "__request_recording=1:#{existing_request.id};foo=bar")
      headers["Set-Cookie"].should include "__request_recording=; expires="
    end
  end

  it "should not record if __request_recording is not given" do
    middleware = RequestRecorder::Middleware.new(inner_app)
    middleware.call(
      "QUERY_STRING" => "stuff=hello", "HTTP_COOKIE" => "bar=foo"
    )
    RequestRecorder::Request.count.should == 0
  end

  it "restores the AR logger after executing" do
    middleware = RequestRecorder::Middleware.new(inner_app)
    middleware.call(activate_logger)

    ActiveRecord::Base.logger.instance_variable_get("@log").object_id.should == original_logger.object_id
    ActiveRecord::Base.logger.auto_flushing.should == 1000
    ActiveRecord::Base.logger.level.should == Logger::ERROR
  end
end
