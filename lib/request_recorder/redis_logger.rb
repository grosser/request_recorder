module RequestRecorder
  class RedisLogger
    KEY = "request_recorder"

    def initialize(store)
      @store = store
    end

    def write(id, text)
      if id
        old = read(id)
      else
        id = "#{Time.now.utc.strftime("%Y-%m-%d %H:%M:%S.%L")}_#{Process.pid}"
      end
      @store.hset(KEY, id, "#{old}#{text}")
      id
    end

    def read(id)
      @store.hget(KEY, id)
    end

    def keys
      @store.hkeys(KEY)
    end
  end
end
