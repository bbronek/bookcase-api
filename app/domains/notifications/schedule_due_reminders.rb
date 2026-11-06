module Notifications
  class ScheduleDueReminders
    def self.call(...) = new(...).call

    def initialize(today: Time.zone.today)
      @today = today
    end

    def call
      reminders = Reminder.kinds.keys.flat_map { |kind| schedule(kind) }
      ActiveJob.perform_all_later(reminders.map { |reminder| DeliverReminderJob.new(reminder) })
      reminders
    end

    private

    def schedule(kind)
      borrowing_ids = Borrowing.active.where(due_on: Reminder.due_dates(kind, today: @today)).pluck(:id)
      rows = borrowing_ids.map { |borrowing_id| { borrowing_id:, kind: } }
      Reminder.insert_all(rows, unique_by: %i[ borrowing_id kind ])
      Reminder.pending.where(kind:, borrowing_id: borrowing_ids).to_a
    end
  end
end
