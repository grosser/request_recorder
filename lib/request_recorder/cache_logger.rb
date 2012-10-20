module RequestRecorder
  class CacheLogger
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
      @store.write(key(id), "#{old}#{text}")
      id
    end

    def read(id)
      @store.read(key(id))
    end

    private

    def key(id)
      "#{KEY}.#{id}"
    end
  end
end
