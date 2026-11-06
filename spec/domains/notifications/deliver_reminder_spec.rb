require "rails_helper"

RSpec.describe Notifications::DeliverReminder do
  let(:reader) { create(:reader, email: "ada@example.com") }
  let(:reminder) { create(:reminder, kind: "due_soon", borrowing: create(:borrowing, :due_soon, reader:)) }

  def deliver = described_class.call(reminder:)

  def mail_server_replies(error, reply) = allow(ActionMailer::Base).to receive(:deliver_mail).and_raise(error, reply)

  it "emails the reader and records when it was sent" do
    freeze_time
    deliver

    expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ "ada@example.com" ] ])
    expect(reminder.reload).to have_attributes(sent_at: Time.current)
  end

  context "with a due-today reminder" do
    let(:reminder) { create(:reminder, kind: "due_today", borrowing: create(:borrowing, :due_today, reader:)) }

    it "sends the due-today email" do
      deliver

      expect(ActionMailer::Base.deliveries.sole.subject).to end_with("is due back today")
    end
  end

  it "sends nothing for a reminder that is no longer deliverable" do
    reminder.update!(sent_at: 1.hour.ago)

    deliver

    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "surfaces a refused delivery and leaves the reminder pending for the next run" do
    mail_server_replies(Net::SMTPFatalError, "550 5.1.1 <ada@example.com>: Recipient address rejected: User unknown")

    expect { deliver }.to raise_error(Net::SMTPFatalError)
    expect(reminder.reload).to be_pending
  end
end
