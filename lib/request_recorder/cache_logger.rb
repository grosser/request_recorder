module RequestRecorder
  class CacheLogger
    KEY = "request_recorder"

    def initialize(store)
      @store = store
    end

    def write(id, text)
      id = "#{KEY}.#{Time.now.utc.strftime("%Y-%m-%d %H:%M:%S.%L")}_#{Process.pid}" unless id
      @store.write(id, @store.read(id).to_s + text)
      id
    end
  end
end
