require "active_record"

ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new("/dev/null")

# connect
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:"
)

# create tables
ActiveRecord::Schema.define(:version => 1) do
  create_table :requests do |t|
    t.text :log
    t.timestamps
  end

  create_table :cars do |t|
    t.timestamps
  end
end

class Car < ActiveRecord::Base
end

require "spec_helper"

describe RequestRecorder do
  let(:original_logger){ ActiveSupport::BufferedLogger.new("/dev/null") }
  let(:active_logger){ {"QUERY_STRING" => "start_request_recording=1"} }

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
    middleware = RequestRecorder::Middleware.new(lambda{|env|
      Car.first
      [200, "assadasd", {}]
    })
    middleware.call(active_logger)
    RequestRecorder::Request.last.log.should include "SELECT"
  end

  it "should not record if start_request_recording is not given" do
    middleware = RequestRecorder::Middleware.new(lambda{|env|
      Car.first
      [200, "assadasd", {}]
    })
    middleware.call(
      "QUERY_STRING" => "stuff=hello"
    )
    RequestRecorder::Request.count.should == 0
  end

  it "restores the AR logger after executing" do
    @log =
    middleware = RequestRecorder::Middleware.new(lambda{|env|
      Car.first
      [200, "assadasd", {}]
    })
    middleware.call(active_logger)

    ActiveRecord::Base.logger.instance_variable_get("@log").object_id.should == original_logger.object_id
    ActiveRecord::Base.logger.auto_flushing.should == 1000
    ActiveRecord::Base.logger.level.should == Logger::ERROR
  end
end
