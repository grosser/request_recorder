require "request_recorder/version"

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

  class Request < ActiveRecord::Base
  end

  class Middleware
    def initialize(app, options={})
      @app = app
    end

    def call(env)
      return @app.call(env) unless env["QUERY_STRING"].include?("start_request_recording=")

      result = logging_to_recorded do
        @app.call(env)
      end

      Request.create!(:log => @recorder.log.join("\n"))

      result
    end

    private

    def logging_to_recorded
      @recorder = Recorder.new
      old = [
        ActiveRecord::Base.logger.instance_variable_get("@log"),
        ActiveRecord::Base.logger.auto_flushing,
        ActiveRecord::Base.logger.level
      ]
      ActiveRecord::Base.logger.instance_variable_set("@log", @recorder)
      ActiveRecord::Base.logger.auto_flushing = true
      ActiveRecord::Base.logger.level = Logger::DEBUG
      yield
    ensure
      ActiveRecord::Base.logger.instance_variable_set("@log", old[0])
      ActiveRecord::Base.logger.auto_flushing = old[1]
      ActiveRecord::Base.logger.level = old[2]
    end
  end
end
