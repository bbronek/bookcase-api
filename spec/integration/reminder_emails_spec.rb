require "rails_helper"

RSpec.describe "Reminder emails" do
  before { travel_to Time.zone.parse("2026-11-04 15:00") }

  let!(:borrowing) do
    Circulation::BorrowBook.call(serial_number: create(:book, title: "Dune").serial_number, card_number: create(:reader).card_number)
  end

  def hourly_runs_on(date)
    (9..21).each do |hour|
      travel_to date.in_time_zone.change(hour:)
      perform_enqueued_jobs { ScheduleDueRemindersJob.perform_now }
    end
  end

  def subjects = ActionMailer::Base.deliveries.map(&:subject)

  it "emails the reader three days before the due date and on it, once each" do
    expect(borrowing.due_on).to eq(Date.new(2026, 12, 4))

    hourly_runs_on(Date.new(2026, 11, 30))
    expect(subjects).to be_empty

    hourly_runs_on(Date.new(2026, 12, 1))
    expect(subjects).to eq([ "Reminder: \"Dune\" is due back on Friday, 4 December 2026" ])

    hourly_runs_on(Date.new(2026, 12, 3))
    hourly_runs_on(Date.new(2026, 12, 4))
    hourly_runs_on(Date.new(2026, 12, 5))
    expect(subjects).to eq([ "Reminder: \"Dune\" is due back on Friday, 4 December 2026", "\"Dune\" is due back today" ])
  end

  it "catches up on a due-soon reminder the next day when every run of a day was missed" do
    hourly_runs_on(Date.new(2026, 12, 2))

    expect(subjects).to eq([ "Reminder: \"Dune\" is due back on Friday, 4 December 2026" ])
  end

  it "stops once the book is returned" do
    hourly_runs_on(Date.new(2026, 12, 1))
    Circulation::ReturnBook.call(borrowing_id: borrowing.id)

    hourly_runs_on(Date.new(2026, 12, 4))

    expect(subjects.size).to eq(1)
  end

  it "never tries an address again once the mail server says it does not exist" do
    allow(ActionMailer::Base).to receive(:deliver_mail).and_raise(Net::SMTPFatalError, "550 5.1.1 User unknown")

    hourly_runs_on(Date.new(2026, 12, 1))
    hourly_runs_on(Date.new(2026, 12, 2))

    expect(ActionMailer::Base).to have_received(:deliver_mail).once
  end
end
