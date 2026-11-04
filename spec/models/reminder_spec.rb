require "rails_helper"

RSpec.describe Reminder do
  describe ".deliver!" do
    let(:borrowing) { create(:borrowing) }

    it "sends the email once and records when it was sent" do
      freeze_time do
        reminder = described_class.deliver!(borrowing, "upcoming")

        expect(reminder).to be_persisted.and be_upcoming
        expect(reminder.sent_at).to eq(Time.current)
      end

      expect(ActionMailer::Base.deliveries.map(&:to)).to eq([ [ borrowing.reader.email ] ])
    end

    it "does not send again for the same borrowing and kind" do
      described_class.deliver!(borrowing, "upcoming")

      expect { described_class.deliver!(borrowing, "upcoming") }
        .to not_change(ActionMailer::Base.deliveries, :size).and not_change(described_class, :count)
    end

    it "sends a different kind of reminder for the same borrowing" do
      described_class.deliver!(borrowing, "upcoming")

      expect { described_class.deliver!(borrowing, "due_today") }.to change(ActionMailer::Base.deliveries, :size).by(1)
    end

    it "retries a reminder that was recorded but never marked as sent" do
      create(:reminder, borrowing:, kind: "upcoming", sent_at: nil)

      expect { described_class.deliver!(borrowing, "upcoming") }.to change(ActionMailer::Base.deliveries, :size).by(1)
    end

    it "rejects unknown kinds" do
      expect { described_class.deliver!(borrowing, "someday") }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
