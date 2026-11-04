require "rails_helper"

RSpec.describe Book do
  subject(:book) { build(:book) }

  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:author) }
  it { is_expected.to validate_presence_of(:serial_number) }
  it { is_expected.to validate_uniqueness_of(:serial_number).ignoring_case_sensitivity }

  it "accepts six-digit serial numbers, including ones with leading zeros" do
    expect(build(:book, serial_number: "000042")).to be_valid
  end

  it "rejects serial numbers that are not exactly six digits" do
    %w[ 12345 1234567 12345a ].each do |serial_number|
      expect(build(:book, serial_number:)).not_to be_valid
    end
  end

  it "enforces the serial number format in the database too" do
    expect { Book.insert!({ serial_number: "1", title: "t", author: "a" }) }
      .to raise_error(ActiveRecord::StatementInvalid, /books_serial_number_six_digits/)
  end

  describe "#status" do
    it "is available without an active borrowing and borrowed with one" do
      book = create(:book)
      expect(book.status).to eq("available")

      create(:borrowing, book:)
      expect(book.reload.status).to eq("borrowed")

      book.return!
      expect(book.status).to eq("available")
    end

    it "ignores returned borrowings" do
      book = create(:borrowing, :returned).book
      expect(book.reload).not_to be_borrowed
    end
  end

  describe "#borrow!" do
    let(:book) { create(:book) }
    let(:reader) { create(:reader) }

    it "creates an active borrowing due 30 days later" do
      now = Time.zone.parse("2026-11-04 15:30")
      borrowing = book.borrow!(reader, now:)

      expect(borrowing).to be_active
      expect(borrowing.reader).to eq(reader)
      expect(borrowing.borrowed_at).to eq(now)
      expect(borrowing.due_on).to eq(Date.new(2026, 12, 4))
      expect(book).to be_borrowed
    end

    it "refuses when the book is already borrowed" do
      book.borrow!(reader)

      expect { book.borrow!(create(:reader)) }.to raise_error(Book::InvalidTransition, /already borrowed/)
      expect(book.borrowings.count).to eq(1)
    end

    it "relies on the database when two requests race for the same book" do
      # Simulate a stale in-memory state: this instance believes the book is free while another request took it.
      create(:borrowing, book:)
      allow(book).to receive(:borrowed?).and_return(false)

      expect { book.borrow!(reader) }.to raise_error(Book::InvalidTransition, /already borrowed/)
      expect(book.borrowings.count).to eq(1)
    end

    it "allows borrowing again after a return" do
      book.borrow!(reader)
      book.return!

      expect { book.borrow!(reader) }.to change { book.borrowings.count }.to(2)
    end
  end

  describe "#return!" do
    let(:book) { create(:book) }

    it "closes the active borrowing" do
      borrowing = book.borrow!(create(:reader), now: Time.zone.parse("2026-10-10 10:00"))
      now = Time.zone.parse("2026-11-04 10:00")

      expect(book.return!(now:)).to eq(borrowing)
      expect(borrowing.reload.returned_at).to eq(now)
      expect(book).not_to be_borrowed
    end

    it "refuses when the book is not borrowed" do
      expect { book.return! }.to raise_error(Book::InvalidTransition, /not borrowed/)
    end
  end

  describe "#destroy" do
    it "is refused while the book is borrowed and keeps the history" do
      book = create(:borrowing).book

      expect(book.destroy).to be(false)
      expect(book.errors[:base]).to include(a_string_matching(/cannot be deleted while borrowed/))
      expect(Borrowing.count).to eq(1)
    end

    it "removes the book together with its borrowing history" do
      book = create(:borrowing, :returned).book
      create(:reminder, borrowing: book.borrowings.first)

      expect { book.destroy! }.to change(Book, :count).by(-1)
        .and change(Borrowing, :count).by(-1)
        .and change(Reminder, :count).by(-1)
    end
  end
end
