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
  let(:key){ RequestRecorder::CacheLogger::KEY }
  let(:logger){ RequestRecorder::CacheLogger.new(store) }

  it_behaves_like "a logger"
end
