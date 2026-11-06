require "rails_helper"

RSpec.describe DeliverReminderJob do
  let(:reminder) { create(:reminder) }

  def mail_server_raises(error, reply) = allow(ActionMailer::Base).to receive(:deliver_mail).and_raise(error, reply)

  it "sends one email however often it runs" do
    2.times { described_class.perform_now(reminder) }

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ reminder.borrowing.reader.email ] ])
    expect(reminder.reload).to be_sent
  end

  it "retries a temporary mail failure with backoff and leaves the reminder pending" do
    mail_server_raises(Net::SMTPServerBusy, "421 try again later")

    expect { described_class.perform_now(reminder) }.to have_enqueued_job(described_class).with(reminder)
    expect(reminder.reload).to be_pending
  end

  it "fails loudly, without retrying, on a configuration problem, and leaves the reminder for the next run" do
    mail_server_raises(Net::SMTPAuthenticationError, "535 authentication failed")

    expect { described_class.perform_now(reminder) }.to raise_error(Net::SMTPAuthenticationError)
    expect(enqueued_jobs).to be_empty
    expect(reminder.reload).to be_pending
  end

  it "lets one worker at a time deliver a reminder and drops duplicates queued meanwhile" do
    expect(described_class.new(reminder)).to have_attributes(
      concurrency_key: end_with(reminder.id), concurrency_limit: 1, concurrency_on_conflict: :discard
    )
  end
end
