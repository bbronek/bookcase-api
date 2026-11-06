class ScheduleDueRemindersJob < ApplicationJob
  def perform = Notifications::ScheduleDueReminders.call
end
