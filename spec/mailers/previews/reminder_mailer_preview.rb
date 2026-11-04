# Preview at http://localhost:3000/rails/mailers/reminder_mailer
class ReminderMailerPreview < ActionMailer::Preview
  def upcoming
    ReminderMailer.with(reminder: reminder("upcoming")).reminder
  end

  def due_today
    ReminderMailer.with(reminder: reminder("due_today")).reminder
  end

  private

  def reminder(kind)
    borrowing = Borrowing.active.first || Borrowing.new(
      book: Book.new(serial_number: "000001", title: "Dune", author: "Frank Herbert"),
      reader: Reader.new(card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com"),
      borrowed_at: 27.days.ago, due_on: 3.days.from_now.to_date
    )
    Reminder.new(borrowing:, kind:)
  end
end
