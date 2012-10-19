module RequestRecorder
  class RedisLogger
    KEY = "request_recorder"

    def initialize(redis)
      @redis = redis
    end

    def write(id, s)
      old = (id ? @redis.hget(KEY, id) : "") #TODO test-case for to_s
      id = "#{Time.now.to_i}_#{Process.pid}" unless id
      @redis.hset(KEY, id, old + s)
      id
    end
  end
end
