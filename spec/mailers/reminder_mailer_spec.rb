require "rails_helper"

RSpec.describe ReminderMailer do
  let(:borrowing) do
    create(:borrowing,
      book: create(:book, serial_number: "000004", title: "Solaris", author: "Stanisław Lem"),
      reader: create(:reader, full_name: "Grace Hopper", email: "grace@example.com"),
      borrowed_at: Time.zone.parse("2026-10-08 10:00"),
      due_on: Date.new(2026, 11, 7))
  end

  describe "#due_soon" do
    subject(:mail) { described_class.with(borrowing:).due_soon }

    it "tells the reader the due date in both parts" do
      expect(mail).to have_attributes(to: [ "grace@example.com" ], from: [ "library@example.com" ],
                                      subject: "Reminder: \"Solaris\" is due back on Saturday, 7 November 2026")
      expect(mail.text_part.decoded).to include("Hello Grace Hopper", "is due back on Saturday, 7 November 2026",
                                                "Stanisław Lem", "000004", "Thursday, 8 October 2026")
      expect(mail.html_part.decoded).to include("Hello Grace Hopper", "<strong>Saturday, 7 November 2026</strong>")
    end
  end

  describe "#due_today" do
    subject(:mail) { described_class.with(borrowing:).due_today }

    it "tells the reader the book is due today" do
      expect(mail.subject).to eq("\"Solaris\" is due back today")
      expect(mail.text_part.decoded).to include("is due back today")
      expect(mail.html_part.decoded).to include("<strong>today</strong>")
    end
  end
end
