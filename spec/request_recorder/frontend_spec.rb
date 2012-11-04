require "spec_helper"

describe RequestRecorder::Frontend do
  describe "#render" do
    it "renders" do
      result = RequestRecorder::Frontend.render("CONTENT")
      result.should include "CONTENT"
    end

    it "converts colors from cli to html" do
      result = RequestRecorder::Frontend.render("\e[4;35;1mxxx\e[0;1m")
      result.should include "<span style='color:red'>xxx</span>"
    end
  end
end
