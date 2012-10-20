require "request_recorder"
require "request_recorder/redis_logger"
require "request_recorder/cache_logger"

require "active_record"
require "fakeredis"

ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new("/dev/null")

# connect
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:"
)

# create tables
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define(:version => 1) do
  create_table :cars do |t|
    t.timestamps
  end
end

class Car < ActiveRecord::Base
end

shared_examples "a logger" do
  context "#read" do
    it "is nil on not found" do
      logger.read("xxx").should == nil
    end

    it "finds" do
      logger.write("xxx", "X")
      logger.read("xxx").should == "X"
    end
  end

  context "#write" do
    it "returns a unique id" do
      old = logger.write(nil, "X")
      sleep 0.01
      old.should_not == logger.write(nil, "X")
    end

    it "returns existing ids" do
      "1111".should == logger.write("1111", "X")
    end

    it "creates a new entry" do
      logger.write("1111", "X")
      logger.read("1111").should == "X"
    end

    it "appends to an existing key" do
      logger.write("1111", "X")
      logger.write("1111", "X")
      logger.read("1111").should == "XX"
    end
  end
end
