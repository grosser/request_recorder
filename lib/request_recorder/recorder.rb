module RequestRecorder
  class Recorder
    attr_reader :log

    def initialize
      @log = []
    end

    def write(s)
      @log << s
    end
  end
end
