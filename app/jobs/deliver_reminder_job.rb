class DeliverReminderJob < ApplicationJob
  limits_concurrency key: ->(reminder) { reminder.id }, on_conflict: :discard
  retry_on(*ApplicationMailer::TEMPORARY_FAILURES, wait: :polynomially_longer, attempts: 5)

  def perform(reminder) = Notifications::DeliverReminder.call(reminder:)
end
