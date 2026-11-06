require "rails_helper"

RSpec.describe Notifications::ScheduleDueReminders do
  let(:today) { Date.new(2026, 11, 4) }

  def borrowing_due_on(due_on, **attributes)
    create(:borrowing, borrowed_at: (due_on - Borrowing::PERIOD).in_time_zone, due_on:, **attributes)
  end

  def schedule = described_class.call(today:)

  it "creates a due-today reminder for borrowings due today and a due-soon reminder for those due in the next three days" do
    due_today = borrowing_due_on(today)
    due_soon = [ 1, 2, 3 ].map { |days| borrowing_due_on(today + days) }

    schedule

    expect(Reminder.all.map { [ it.borrowing, it.kind ] })
      .to contain_exactly([ due_today, "due_today" ], *due_soon.map { [ it, "due_soon" ] })
  end

  it "queues one delivery for every pending reminder" do
    borrowing_due_on(today)
    borrowing_due_on(today + 2)

    reminders = []
    expect { reminders = schedule }.to have_enqueued_job(DeliverReminderJob).exactly(2).times
    expect(reminders).to match_array(Reminder.all)
  end

  it "leaves borrowings due later, already overdue or returned alone" do
    borrowing_due_on(today + 4)
    borrowing_due_on(today - 1)
    borrowing_due_on(today, returned_at: today.in_time_zone)

    expect(schedule).to be_empty
    expect(Reminder.count).to eq(0)
  end

  it "keeps one reminder per borrowing and kind, and queues only the pending ones" do
    sent = borrowing_due_on(today + 1)
    pending = borrowing_due_on(today + 3)
    schedule

    Reminder.find_by!(borrowing: sent).update!(sent_at: Time.current)

    expect(schedule.map(&:borrowing)).to eq([ pending ])
    expect(Reminder.count).to eq(2)
  end
end
