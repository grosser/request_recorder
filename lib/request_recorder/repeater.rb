module RequestRecorder
  class Repeater
    def initialize(targets)
      @targets = targets
    end

    # Rails 2
    def write(*args)
      @targets.each{|t| t.write(*args) }
    end

    # Rails 3
    def add(*args)
      @targets.each do |t|
        if t.respond_to?(:add)
          t.add(*args)
        else
          t.write("#{args[1]}\n")
        end
      end
    end

    def level=(x)
      @targets.each{|t| t.level = x if t.respond_to?(:level=) }
    end

    def level
      @targets.detect{|t| t.respond_to?(:level) }.level
    end
  end
end
