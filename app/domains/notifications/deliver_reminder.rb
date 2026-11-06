module Notifications
  class DeliverReminder
    def self.call(...) = new(...).call

    def initialize(reminder:)
      @reminder = reminder
    end

    def call
      return unless @reminder.deliverable?

      ReminderMailer.with(borrowing: @reminder.borrowing).public_send(@reminder.kind).deliver_now
      @reminder.update!(sent_at: Time.current)
    end
  end
end
