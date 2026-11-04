# A reminder email that was (or is about to be) sent for a borrowing.
# One row per (borrowing, kind), enforced by a unique index, which is what makes the daily job idempotent.
class Reminder < ApplicationRecord
  # How many days before the due date each kind of reminder is sent.
  DAYS_BEFORE_DUE = { "upcoming" => 3, "due_today" => 0 }.freeze

  belongs_to :borrowing

  enum :kind, DAYS_BEFORE_DUE.keys.index_by(&:itself), validate: true

  scope :sent, -> { where.not(sent_at: nil) }

  # Sends the email once. Safe to call again for the same borrowing and kind: a second call is a no-op.
  # Delivery is at-least-once: if the process dies between deliver_now and the update, a retry resends.
  def self.deliver!(borrowing, kind)
    reminder = create_or_find_by!(borrowing:, kind:)
    return reminder if reminder.sent_at?

    ReminderMailer.with(reminder:).reminder.deliver_now
    reminder.update!(sent_at: Time.current)
    reminder
  end
end
