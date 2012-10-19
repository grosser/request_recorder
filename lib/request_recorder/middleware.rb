require "stringio"
require "rack/request"
require "rack/response"

module RequestRecorder
  class Middleware
    MARKER = "__request_recording"
    MAX_STEPS = 100

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
      if request.cookies[MARKER]
        request.cookies[MARKER].split(":").map(&:to_i)
      else
        [env["QUERY_STRING"][/#{MARKER}=(\d+)/, 1].to_i, nil]
      end
    end

    def response_with_data_in_cookie(result, to_go, id)
      status, headers, body = result
      response = Rack::Response.new(body, status, headers)
      if to_go <= 1
        response.delete_cookie(MARKER)
      else
        response.set_cookie(MARKER, {:value => "#{to_go.to_i - 1}:#{id}", :expires => Time.now+24*60*60, :httponly => true})
      end

      response.finish # finish writes out the response in the expected format.
    end

    def capture_logging
      recorder = StringIO.new
      old = [
        ActiveRecord::Base.logger.instance_variable_get("@log"),
        ActiveRecord::Base.logger.auto_flushing,
        ActiveRecord::Base.logger.level
      ]
      ActiveRecord::Base.logger.instance_variable_set("@log", recorder)
      ActiveRecord::Base.logger.auto_flushing = true
      ActiveRecord::Base.logger.level = Logger::DEBUG
      yield
      recorder.string
    ensure
      if old
        ActiveRecord::Base.logger.instance_variable_set("@log", old[0])
        ActiveRecord::Base.logger.auto_flushing = old[1]
        ActiveRecord::Base.logger.level = old[2]
      end
    end
  end
end
