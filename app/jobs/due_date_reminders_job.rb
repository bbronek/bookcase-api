# Runs once a day (config/recurring.yml). Finds active borrowings that are due in 3 days or today
# and sends the matching reminder. Re-running for the same day never sends twice (see Reminder.deliver!).
# +today+ is a parameter so a missed day can be replayed: DueDateRemindersJob.perform_later(Date.yesterday).
class DueDateRemindersJob < ApplicationJob
  def perform(today = Date.current)
    Reminder::DAYS_BEFORE_DUE.each do |kind, days_before_due|
      Borrowing.active.where(due_on: today + days_before_due).includes(:book, :reader).find_each do |borrowing|
        Reminder.deliver!(borrowing, kind)
      end
    end
  end
end
