require "rails_helper"

RSpec.describe Catalog::AddBook do
  def add(serial_number: "000001", title: "Dune", author: "Frank Herbert")
    described_class.call(serial_number:, title:, author:)
  end

  it "adds a book to the catalog" do
    book = add

    expect(book).to be_persisted.and(be_previously_new_record)
    expect(book).to have_attributes(serial_number: "000001", title: "Dune", author: "Frank Herbert", status: "available")
  end

  it "rejects invalid attributes before touching the catalog" do
    expect { add(serial_number: "12", title: "") }.to raise_error(ActiveRecord::RecordInvalid) { |error|
      expect(error.record.errors.to_hash).to eq(serial_number: [ "must be exactly six digits" ], title: [ "can't be blank" ])
    }
    expect(Book.count).to eq(0)
  end

  it "refuses a duplicate even when its attributes are identical" do
    add

    expect { add }.to raise_error(Catalog::AddBook::SerialNumberTaken)
    expect(Book.count).to eq(1)
  end

  it "refuses a serial number that belongs to a different book" do
    add

    expect { add(title: "Dune Messiah") }.to raise_error(Catalog::AddBook::SerialNumberTaken, "Serial number 000001 is already registered")
  end

  it "never reuses the serial number of a withdrawn book" do
    create(:book, :withdrawn, serial_number: "000001", title: "Dune", author: "Frank Herbert")

    expect { add }.to raise_error(Catalog::AddBook::SerialNumberTaken)
  end
end
