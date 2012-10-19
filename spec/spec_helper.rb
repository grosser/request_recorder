require "request_recorder"

require "active_record"
require "fakeredis"

ActiveRecord::Base.logger = ActiveSupport::BufferedLogger.new("/dev/null")

# connect
ActiveRecord::Base.establish_connection(
  :adapter => "sqlite3",
  :database => ":memory:"
)

# create tables
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define(:version => 1) do
  create_table :cars do |t|
    t.timestamps
  end
end

class Car < ActiveRecord::Base
end
