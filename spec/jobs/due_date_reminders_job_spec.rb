require "rails_helper"

RSpec.describe DueDateRemindersJob do
  let(:today) { Date.new(2026, 11, 4) }

  def borrowing_due_on(due_on, **attributes)
    create(:borrowing, book: create(:book, title: "Dune"), borrowed_at: (due_on - Borrowing::PERIOD).in_time_zone, due_on:, **attributes)
  end

  def deliveries_to(borrowing)
    ActionMailer::Base.deliveries.select { |mail| mail.to == [ borrowing.reader.email ] }
  end

  it "reminds readers 3 days before the due date and on the due date" do
    upcoming = borrowing_due_on(today + 3)
    due_today = borrowing_due_on(today)

    travel_to(today.noon) { described_class.perform_now }

    expect(deliveries_to(upcoming).map(&:subject)).to eq([ "\"Dune\" is due back in 3 days" ])
    expect(deliveries_to(due_today).map(&:subject)).to eq([ "\"Dune\" is due back today" ])
    expect(Reminder.sent.pluck(:borrowing_id, :kind)).to contain_exactly([ upcoming.id, "upcoming" ], [ due_today.id, "due_today" ])
  end

  it "leaves other borrowings alone" do
    borrowing_due_on(today + 4)
    borrowing_due_on(today + 2)
    borrowing_due_on(today - 1)
    borrowing_due_on(today, returned_at: today.in_time_zone)

    travel_to(today.noon) { described_class.perform_now }

    expect(ActionMailer::Base.deliveries).to be_empty
    expect(Reminder.count).to eq(0)
  end

  it "does not send duplicates when run more than once on the same day" do
    borrowing_due_on(today + 3)

    travel_to(today.noon) { 2.times { described_class.perform_now } }

    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "sends both reminders for one borrowing over the loan period" do
    borrowing = borrowing_due_on(today + 3)

    travel_to(today.noon) { described_class.perform_now }
    travel_to((today + 3).noon) { described_class.perform_now }

    expect(deliveries_to(borrowing).size).to eq(2)
  end

  it "can be replayed for a missed day" do
    borrowing_due_on(today + 3)

    travel_to((today + 1).noon) { described_class.perform_now(today) }

    expect(ActionMailer::Base.deliveries.size).to eq(1)
  end

  it "is scheduled to run daily" do
    task = Rails.application.config_for(:recurring, env: "production")[:due_date_reminders]

    expect(task[:class]).to eq("DueDateRemindersJob")
    expect(task[:schedule]).to eq("every day at 9am")
  end
end
