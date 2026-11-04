require "rails_helper"

RSpec.describe ReminderMailer do
  let(:book) { create(:book, title: "Solaris", author: "Stanisław Lem", serial_number: "000004") }
  let(:reader) { create(:reader, full_name: "Grace Hopper", email: "grace@example.com") }
  let(:borrowing) { create(:borrowing, book:, reader:, borrowed_at: Time.zone.parse("2026-10-08 10:00"), due_on: Date.new(2026, 11, 7)) }

  it "builds the 3-days-before reminder" do
    mail = described_class.with(reminder: build(:reminder, borrowing:, kind: "upcoming")).reminder

    expect(mail.to).to eq([ "grace@example.com" ])
    expect(mail.from).to eq([ "library@example.com" ])
    expect(mail.subject).to eq("\"Solaris\" is due back in 3 days")
    expect(mail.body.encoded).to include("Hello Grace Hopper", "due back in 3 days", "Solaris", "Stanisław Lem", "000004", "2026-10-08", "2026-11-07")
  end

  it "builds the due-today reminder" do
    mail = described_class.with(reminder: build(:reminder, borrowing:, kind: "due_today")).reminder

    expect(mail.subject).to eq("\"Solaris\" is due back today")
    expect(mail.body.encoded).to include("due back today")
  end
end
