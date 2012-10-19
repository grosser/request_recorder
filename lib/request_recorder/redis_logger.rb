module RequestRecorder
  class RedisLogger
    KEY = "request_recorder"

    def initialize(redis)
      @redis = redis
    end

    def write(id, text)
      old = (id ? @redis.hget(KEY, id) : "")
      id = "#{Time.now.to_i}_#{Process.pid}" unless id
      @redis.hset(KEY, id, old.to_s + text)
      id
    end
  end
end
