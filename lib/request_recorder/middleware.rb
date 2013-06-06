require "stringio"
require "rack/request"
require "rack/response"
require "request_recorder/frontend"
require "active_record"
require "rack"
require "rack/body_proxy" if defined?(Rack.release) && Rack.release >= "1.5"
require "base64"
require "multi_json"
require "logcast/rails"

module RequestRecorder
  class Middleware
    MARKER = "request_recorder"
    MAX_STEPS = 100
    SEPARATOR = "-"
    AUTH = :frontend_auth

    def initialize(app, options={})
      @app = app
      @store = options.fetch(:store)
      @auth = options[AUTH]
      @headers = options[:headers] || {}
    end

    def call(env)
      # keep this part as fast as possible, since 99.99999% of requests will not need it
      return @app.call(env) unless "#{env["PATH_INFO"]}-#{env["QUERY_STRING"]}-#{env["HTTP_COOKIE"]}" =~ /#{MARKER}[\/=]/

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
          raise result # Do not mess up the apps normal exception behavior
        else
          path = [env["PATH_INFO"], env["QUERY_STRING"]].compact.join("?")
          if @auth && auth = @auth.call(env)
            extra_headers = chrome_logger_headers(log, path) unless auth.is_a?(Array)
          end
          response_with_data_in_cookie(result, steps_left, id, extra_headers)
        end
      end
    end

    private

    def render_frontend(env, key)
      if @auth
        if response = @auth.call(env)
          if response.is_a?(Array)
            response
          else
            if log = @store.read(key)
              [200, {}, Frontend.render(log)]
            else
              [404, {}, "Did not find a log for key #{key}"]
            end
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

    def response_with_data_in_cookie(result, to_go, id, extra_headers)
      status, headers, body = result
      response = Rack::Response.new(body, status, headers.merge(extra_headers || {}))
      if to_go <= 1
        response.delete_cookie(MARKER)
      else
        response.set_cookie(MARKER, {:value => "#{to_go.to_i - 1}#{SEPARATOR}#{id}", :expires => Time.now+24*60*60, :httponly => true})
      end

      response.finish # finish writes out the response in the expected format.
    end

    def chrome_logger_headers(log, path)
      log = log.split("\n").map { |line| remove_console_colors(line) }
      log = reduce_header_size(log) if @headers


      # fake chrome-logger format
      rows = []
      rows << [["Rails log #{path}"],"xxx.rb:1","group"]
      rows.concat log.map{|line| [line.split(" "), "xxx.rb:1", ""] }
      rows << [[], "xxx.rb:1", "groupEnd"]

      data = {
        'version' => "0.1.1",
        'columns' => [ 'log' , 'backtrace' , 'type' ],
        'rows'    => rows
      }

      # encode
      data = MultiJson.dump(data)
      data = data.encode("UTF-8") if defined?(Encoding)
      data = Base64.encode64(data).gsub("\n", "")

      {"X-ChromeLogger-Data" => data}
    end

    def reduce_header_size(array)
      size = @headers.fetch(:max)
      return array if array.sum(&:size) <= size

      size -= 20 # make room for removed message
      removed_count = 0
      removed_match = []

      unimportant = (@headers[:remove] || []).dup

      while array.sum(&:size) > size
        if remove = unimportant.shift
          removed_match << remove
          array.reject! { |line| line =~ remove }
        else
          removed_count += 1
          array.shift
        end
      end

      # tell user what was removed
      message = []
      message << "all #{removed_match.map(&:inspect).join(", ")}" if removed_match.any?
      message << "#{removed_count} lines" if removed_count > 0
      array << "Removed: #{message.join(", ")}"

      array
    end

    def remove_console_colors(string)
      string.gsub(/\e\[[\d;]+m/, "")
    end

    def capture_logging(&block)
      logger = ActiveRecord::Base.logger
      recorder = StringIO.new
      debug_level(logger){ logger.subscribe(Logger.new(recorder), &block) }
      recorder.string
    end

    def debug_level(logger)
      old, logger.level = logger.level, Logger::DEBUG
      yield
    ensure
      logger.level = old
    end
  end
end
