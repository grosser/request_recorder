require "stringio"
require "rack/request"
require "rack/response"
require "request_recorder/repeater"
require "active_record"

module RequestRecorder
  class Middleware
    MARKER = "__request_recording"
    MAX_STEPS = 100
    SEPARATOR = "|"
    NEED_AUTOFLUSH = (ActiveRecord::VERSION::MAJOR == 2)

    def initialize(app, options={})
      @app = app
      @store = options.fetch(:store)
    end

    def call(env)
      # keep this part as fast as possible, since 99.99999% of requests will not need it
      return @app.call(env) unless (
        (env["QUERY_STRING"] && env["QUERY_STRING"].include?(MARKER)) or
        (env["HTTP_COOKIE"] && env["HTTP_COOKIE"].include?(MARKER))
      )

      result = nil
      log = capture_logging do
        result = @app.call(env)
      end

      steps_left, id = read_state_from_env(env)
      return [500, {}, "__request_recording exceeded maximum value #{MAX_STEPS}"] if steps_left > MAX_STEPS
      id = persist_log(id, log)
      response_with_data_in_cookie(result, steps_left, id)
    end

    private

    def persist_log(id, log)
      @store.write(id, log)
    end

    def read_state_from_env(env)
      request = Rack::Request.new(env)
      value = request.cookies[MARKER] || env["QUERY_STRING"][/#{MARKER}=([^&]+)/, 1]
      steps, id = value.split(SEPARATOR)
      [steps.to_i, id]
    end

    def response_with_data_in_cookie(result, to_go, id)
      status, headers, body = result
      response = Rack::Response.new(body, status, headers)
      if to_go <= 1
        response.delete_cookie(MARKER)
      else
        response.set_cookie(MARKER, {:value => "#{to_go.to_i - 1}#{SEPARATOR}#{id}", :expires => Time.now+24*60*60, :httponly => true})
      end

      response.finish # finish writes out the response in the expected format.
    end

    def capture_logging
      old = [
        ActiveRecord::Base.logger.instance_variable_get("@log"),
        (ActiveRecord::Base.logger.auto_flushing if NEED_AUTOFLUSH),
        ActiveRecord::Base.logger.level
      ]

      recorder = StringIO.new
      repeater = Repeater.new([recorder, old[0]])

      ActiveRecord::Base.logger.instance_variable_set("@log", repeater)
      ActiveRecord::Base.logger.auto_flushing = true if NEED_AUTOFLUSH
      ActiveRecord::Base.logger.level = Logger::DEBUG
      yield
      recorder.string
    ensure
      if old
        ActiveRecord::Base.logger.instance_variable_set("@log", old[0])
        ActiveRecord::Base.logger.auto_flushing = old[1] if NEED_AUTOFLUSH
        ActiveRecord::Base.logger.level = old[2]
      end
    end
  end
end
