require "active_record"

module RequestRecorder
  class Log < ActiveRecord::Base
    set_table_name "recorded_request_log" # TODO use self.table_name = in rails 3
  end
end
