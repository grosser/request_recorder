module RequestRecorder
  class CacheLogger
    KEY = "request_recorder"

    def initialize(store)
      @store = store
    end

    def write(id, text)
      id = "#{Time.now.utc.strftime("%Y-%m-%d %H:%M:%S.%L")}_#{Process.pid}" unless id
      key = "#{KEY}.#{id}"
      @store.write(key, @store.read(key).to_s + text)
      id
    end
  end
end
