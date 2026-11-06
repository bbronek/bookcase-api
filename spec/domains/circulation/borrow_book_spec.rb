require "rails_helper"

RSpec.describe Circulation::BorrowBook do
  let(:book) { create(:book, serial_number: "000001") }
  let(:reader) { create(:reader, card_number: "100001") }

  def borrow(serial_number: book.serial_number, card_number: reader.card_number, borrowed_at: nil)
    described_class.call(serial_number:, card_number:, borrowed_at:)
  end

  it "lends the book to the reader for 30 days" do
    travel_to Time.zone.parse("2026-11-04 15:30")

    borrowing = borrow

    expect(borrowing).to be_previously_new_record
    expect(borrowing).to have_attributes(book:, reader:, borrowed_at: Time.current, due_on: Date.new(2026, 12, 4), returned_at: nil)
    expect(book.reload.status).to eq("borrowed")
  end

  it "records an earlier borrow time when one is given" do
    borrowing = borrow(borrowed_at: Time.zone.parse("2026-10-01 12:00"))

    expect(borrowing).to have_attributes(borrowed_at: Time.zone.parse("2026-10-01 12:00"), due_on: Date.new(2026, 10, 31))
  end

  it "refuses a repeated request by the same reader" do
    borrow

    expect { borrow }.to raise_error(described_class::BookAlreadyBorrowed)
    expect(book.borrowings.count).to eq(1)
  end

  it "refuses when another reader has the book" do
    borrow

    expect { borrow(card_number: create(:reader).card_number) }
      .to raise_error(described_class::BookAlreadyBorrowed, "Book 000001 is already borrowed")
  end

  it "lends the book again once it has been returned" do
    Circulation::ReturnBook.call(borrowing_id: borrow.id)

    expect(borrow).to be_previously_new_record.and(have_attributes(reader:, returned_at: nil))
    expect(book.borrowings.count).to eq(2)
  end

  it "rejects a card number that matches no reader, pointing at the card number" do
    expect { borrow(card_number: "999999") }.to raise_error(described_class::UnknownReader, "does not match any reader") { |error|
      expect(error.attribute).to eq(:card_number)
    }
  end

  it "rejects a missing card number before touching the book" do
    expect { borrow(card_number: " ", serial_number: "999999") }.to raise_error(described_class::CardNumberMissing, "can't be blank")
  end

  it "refuses a withdrawn book and does not find unknown ones" do
    withdrawn = create(:book, :withdrawn)

    expect { borrow(serial_number: withdrawn.serial_number) }.to raise_error(Catalog::BookWithdrawn)
    expect { borrow(serial_number: "999999") }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
