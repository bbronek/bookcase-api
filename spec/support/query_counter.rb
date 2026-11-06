module QueryCounter
  def count_queries(&)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:cached] || payload[:name].in?(%w[ SCHEMA TRANSACTION ]) }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCounter
end
