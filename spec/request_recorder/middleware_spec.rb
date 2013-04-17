require "spec_helper"

describe RequestRecorder::Middleware do
  describe "#reduce_header_size" do
    let(:middleware) { RequestRecorder::Middleware.new(nil, :store => {}, :headers => {:max => 100, :remove => [/b/]}) }

    it "does not touch small" do
      middleware.send(:reduce_header_size, ["a"*40, "b"*40]).should == ["a"*40, "b"*40]
    end

    it "removes from the front and notifies of removal" do
      middleware.send(:reduce_header_size, ["a"*60, "c"*60]).should == ["c"*60, "Removed: all /b/, 1 lines"]
    end

    it "removes :header :remove when above max before other things" do
      middleware.send(:reduce_header_size, ["a" * 40,"b"*40,"c" * 40]).should == [
        "a" * 40, "c" * 40, "Removed: all /b/"
      ]
    end
  end
end
