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
    rescue Net::SMTPFatalError => error
      raise unless ApplicationMailer.unknown_recipient?(error)

      @reminder.update!(failed_at: Time.current)
      Rails.logger.warn("Reminder #{@reminder.id} failed: the mail server does not know the reader's address")
    end
  end
end
