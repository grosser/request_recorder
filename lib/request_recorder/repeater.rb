module RequestRecorder
  class Repeater
    def initialize(targets)
      @targets = targets
    end

    def write(*args)
      @targets.each{|t| t.write(*args) }
    end
  end
end
