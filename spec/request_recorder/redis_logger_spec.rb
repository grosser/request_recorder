require "spec_helper"

describe RequestRecorder::RedisLogger do
  let(:store){ FakeRedis::Redis.new }
  let(:key){ RequestRecorder::RedisLogger::KEY }
  let(:logger){ RequestRecorder::RedisLogger.new(store) }

  before do
    # TODO this should not be necessary ...
    # but BUNDLE_GEMFILE=gemfiles/rails2.gemfile rspec spec/ fails without
    store.flushall
  end

  it_behaves_like "a logger"

  context "#keys" do
    it "lists the keys" do
      logger.write("xxx", "X")
      logger.keys.should == ["xxx"]
    end

    it "returns empty array for empty keys" do
      logger.keys.should == []
    end
  end
end
