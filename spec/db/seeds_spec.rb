require "rails_helper"

RSpec.describe "Seeds" do
  def seed = Rails.application.load_seed

  it "loads a demo library ready for the reminder emails in development, and can be loaded again" do
    travel_to Time.zone.parse("2026-11-04 10:00")
    allow(Rails.env).to receive(:development?).and_return(true)

    2.times { seed }

    expect(books: Book.count, readers: Reader.count, borrowings: Borrowing.count, active: Borrowing.active.count)
      .to eq(books: 5, readers: 3, borrowings: 4, active: 3)
    expect(Notifications::ScheduleDueReminders.call.map(&:kind)).to contain_exactly("due_today", "due_soon")
  end

  it "never runs outside development" do
    seed

    expect(Book.count).to eq(0)
  end
end
