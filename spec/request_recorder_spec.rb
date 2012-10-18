require "spec_helper"

describe RequestRecorder do
  it "has a VERSION" do
    RequestRecorder::VERSION.should =~ /^[\.\da-z]+$/
  end
end
