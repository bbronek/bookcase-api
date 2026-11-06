# == Schema Information
#
# Table name: reminders
#
#  id           :uuid             not null, primary key
#  failed_at    :datetime
#  kind         :enum             not null, enum_type: reminder_kind
#  sent_at      :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  borrowing_id :uuid             not null
#
# Indexes
#
#  index_reminders_on_borrowing_id_and_kind  (borrowing_id,kind) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (borrowing_id => borrowings.id)
#
# Check Constraints
#
#  reminders_sent_or_failed  (sent_at IS NULL OR failed_at IS NULL)
#
# Enums
#
#  reminder_kind  due_soon, due_today
#
class Reminder < ApplicationRecord
  DUE_SOON_PERIOD = 3.days
  DUE_DATES = {
    "due_today" => ->(today) { today..today },
    "due_soon" => ->(today) { today.next_day..(today + DUE_SOON_PERIOD) }
  }.freeze

  belongs_to :borrowing, inverse_of: :reminders

  enum :kind, { due_soon: "due_soon", due_today: "due_today" }, validate: true

  scope :pending, -> { where(sent_at: nil, failed_at: nil) }

  def sent? = sent_at?

  def failed? = failed_at?

  def pending? = !sent? && !failed?

  def self.due_dates(kind, today: Time.zone.today) = DUE_DATES.fetch(kind).call(today)

  def deliverable? = pending? && !borrowing.returned? && Reminder.due_dates(kind).cover?(borrowing.due_on)
end
