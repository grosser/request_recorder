module RequestRecorder
  class RedisLogger
    KEY = "request_recorder"

    def initialize(redis)
      @redis = redis
    end

    def write(id, text)
      old = (id ? @redis.hget(KEY, id) : "")
      id = "#{Time.now.utc.strftime("%Y-%m-%d %H:%M:%S.%L")}_#{Process.pid}" unless id
      @redis.hset(KEY, id, old.to_s + text)
      id
    end
  end
end
