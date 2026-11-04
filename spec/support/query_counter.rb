# Counts SQL statements issued inside the block (schema and transaction statements excluded).
module QueryCounter
  def count_queries
    count = 0
    counter = lambda do |_name, _start, _finish, _id, payload|
      count += 1 unless payload[:cached] || payload[:name].in?(%w[ SCHEMA TRANSACTION ])
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    count
  end
end

RSpec.configure do |config|
  config.include QueryCounter, type: :request
end
