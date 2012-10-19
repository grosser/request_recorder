require "spec_helper"

describe RequestRecorder::CacheLogger do
  class Store
    def initialize
      @data = {}
    end

    def read(x)
      @data[x]
    end

    def write(x,y)
      @data[x] = y
    end
  end

  let(:store){ Store.new }
  let(:logger){ RequestRecorder::CacheLogger.new(store) }

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
      store.read("1111").should == "X"
    end

    it "appends to an existing key" do
      logger.write("1111", "X")
      logger.write("1111", "X")
      store.read("1111").should == "XX"
    end
  end
end
