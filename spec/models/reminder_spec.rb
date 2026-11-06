require "rails_helper"

RSpec.describe Reminder do
  it { is_expected.to define_enum_for(:kind).with_values(due_soon: "due_soon", due_today: "due_today").backed_by_column_of_type(:enum).validating }

  describe "database guards, with validations bypassed" do
    let(:borrowing) { create(:borrowing) }

    def insert(**attributes) = described_class.insert!({ borrowing_id: borrowing.id, kind: "due_soon", **attributes })

    it "allows one reminder of each kind per borrowing" do
      insert(kind: "due_soon")
      insert(kind: "due_today")

      expect { insert(kind: "due_soon") }.to raise_error(ActiveRecord::RecordNotUnique, /index_reminders_on_borrowing_id_and_kind/)
    end

    it "accepts only the kinds of the reminder_kind enum" do
      expect { insert(kind: "overdue") }.to raise_error(ActiveRecord::StatementInvalid, /invalid input value for enum reminder_kind/)
    end

    it "rejects a borrowing that does not exist" do
      expect { insert(borrowing_id: SecureRandom.uuid_v7) }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe ".due_dates" do
    let(:today) { Date.new(2026, 11, 4) }

    it "covers today for a due-today reminder and the next three days for a due-soon reminder" do
      expect(described_class.due_dates("due_today", today:)).to eq(today..today)
      expect(described_class.due_dates("due_soon", today:)).to eq(Date.new(2026, 11, 5)..Date.new(2026, 11, 7))
    end
  end

  describe "#deliverable?" do
    let(:borrowing) { create(:borrowing, :due_soon) }
    let(:due_soon) { create(:reminder, borrowing:, kind: "due_soon") }
    let(:due_today) { create(:reminder, borrowing:, kind: "due_today") }

    def on_the_due_date = travel_to(borrowing.due_on.in_time_zone.change(hour: 9))

    it "is deliverable while pending and the book is still borrowed" do
      expect(due_soon).to be_deliverable

      expect(build(:reminder, :sent, borrowing:)).not_to be_deliverable

      borrowing.returned_at = Time.current
      expect(due_soon).not_to be_deliverable
    end

    it "delivers a due-soon reminder before the due date, never from it on" do
      on_the_due_date
      expect(due_soon).not_to be_deliverable

      travel 1.day
      expect(due_soon).not_to be_deliverable
    end

    it "delivers a due-today reminder on the due date only, never once the book is overdue" do
      expect(due_today).not_to be_deliverable

      on_the_due_date
      expect(due_today).to be_deliverable

      travel 1.day
      expect(due_today).not_to be_deliverable
    end
  end

  it "is pending until it is sent" do
    reminder = create(:reminder)

    expect { reminder.update!(sent_at: Time.current) }.to change { described_class.pending.count }.from(1).to(0)
    expect(reminder).not_to be_pending
  end
end
