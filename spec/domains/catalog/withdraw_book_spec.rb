require "rails_helper"

RSpec.describe Catalog::WithdrawBook do
  it "takes the book out of the catalog and keeps its history" do
    book = create(:borrowing, :returned).book

    freeze_time do
      expect(described_class.call(serial_number: book.serial_number)).to have_attributes(withdrawn_at: Time.current)
    end
    expect(Book.in_catalog).not_to include(book)
    expect(book.borrowings.count).to eq(1)
  end

  it "refuses to withdraw a borrowed book" do
    book = create(:borrowing).book

    expect { described_class.call(serial_number: book.serial_number) }
      .to raise_error(Circulation::BookBorrowed, "Book #{book.serial_number} is currently borrowed")
    expect(book.reload.withdrawn_at).to be_nil
  end

  it "is idempotent: withdrawing a withdrawn book changes nothing" do
    withdrawn = create(:book, :withdrawn)

    expect { described_class.call(serial_number: withdrawn.serial_number) }.not_to(change { withdrawn.reload.withdrawn_at })
  end

  it "does not find unknown books" do
    expect { described_class.call(serial_number: "999999") }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
