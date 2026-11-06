class ReminderMailerPreview < ActionMailer::Preview
  def due_soon = ReminderMailer.with(borrowing: borrowing_due_in(Reminder::DUE_SOON_PERIOD)).due_soon

  def due_today = ReminderMailer.with(borrowing: borrowing_due_in(0.days)).due_today

  private

  def borrowing_due_in(duration)
    borrowed_at = Time.current + duration - Borrowing::PERIOD
    Borrowing.new(
      book: Book.new(serial_number: "000001", title: "Dune", author: "Frank Herbert"),
      reader: Reader.new(card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com"),
      borrowed_at:,
      due_on: Borrowing.due_on_for(borrowed_at)
    )
  end
end
