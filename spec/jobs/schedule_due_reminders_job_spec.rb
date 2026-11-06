require "rails_helper"
require "fugit"

RSpec.describe ScheduleDueRemindersJob do
  before { travel_to Time.zone.parse("2026-11-04 09:00") }

  let!(:due_today) { create(:borrowing, :due_today) }
  let!(:due_soon) { create(:borrowing, :due_soon) }

  it "sends each email once, however many hourly runs there are" do
    perform_enqueued_jobs { 3.times { described_class.perform_now } }

    expect(ActionMailer::Base.deliveries.map(&:subject)).to contain_exactly(
      "\"#{due_today.book.title}\" is due back today",
      "Reminder: \"#{due_soon.book.title}\" is due back on Saturday, 7 November 2026"
    )
  end

  it "runs every hour from 9am to 9pm library time, so a failed delivery is tried again the same day" do
    schedule = Fugit.parse(Rails.application.config_for(:recurring, env: "production").dig(:schedule_due_reminders, :schedule))
    runs = schedule.next(Time.zone.parse("2026-11-04 08:30")).take(14).map { it.to_t.in_time_zone.strftime("%H:%M") }

    expect(runs).to eq(%w[ 09:00 10:00 11:00 12:00 13:00 14:00 15:00 16:00 17:00 18:00 19:00 20:00 21:00 09:00 ])
  end
end
