require "stringio"
require "rack/request"
require "rack/response"
require "request_recorder/repeater"
require "request_recorder/frontend"
require "active_record"

module RequestRecorder
  class Middleware
    MARKER = "request_recorder"
    MAX_STEPS = 100
    SEPARATOR = "|"
    NEED_AUTOFLUSH = (ActiveRecord::VERSION::MAJOR == 2)
    AUTH = :frontend_auth

    def initialize(app, options={})
      @app = app
      @store = options.fetch(:store)
      @auth = options[AUTH]
    end

    def call(env)
      # keep this part as fast as possible, since 99.99999% of requests will not need it
      return @app.call(env) unless "#{env["PATH_INFO"]}-#{env["QUERY_STRING"]}-#{env["HTTP_COOKIE"]}".include?(MARKER)

      if env["PATH_INFO"].to_s.starts_with?("/#{MARKER}/")
        key = env["PATH_INFO"].split("/")[2]
        render_frontend(env, key)
      else
        result = nil
        log = capture_logging do
          begin
            result = @app.call(env)
          rescue Exception => e
            result = e
          end
        end

        steps_left, id = read_state_from_env(env)
        return [500, {}, "#{MARKER} exceeded maximum value #{MAX_STEPS}"] if steps_left > MAX_STEPS
        id = persist_log(id, log)

        if result.is_a?(Exception)
          raise result
        else
          response_with_data_in_cookie(result, steps_left, id)
        end
      end
    end

    private

    def render_frontend(env, key)
      if @auth
        if @auth.call(env)
          if log = @store.read(key)
            [200, {}, Frontend.render(log)]
          else
            [404, {}, "Did not find a log for key #{key}"]
          end
        else
          [401, {}, "Unauthorized"]
        end
      else
        [500, {}, "you need to provide #{AUTH.inspect} option"]
      end
    end

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
