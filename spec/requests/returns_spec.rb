require "rails_helper"

RSpec.describe "Returning a book" do
  let!(:book) { create(:book, serial_number: "000001") }

  it "marks the book as available again" do
    borrowing = book.borrow!(create(:reader), now: Time.zone.parse("2026-10-10 10:00"))

    travel_to Time.zone.parse("2026-11-04 10:00") do
      post "/books/000001/return"
    end

    expect(response).to have_http_status(:ok)
    expect(json).to include(id: borrowing.id, borrowed_at: "2026-10-10T10:00:00.000Z", returned_at: "2026-11-04T10:00:00.000Z")
    expect(json[:book]).to eq(serial_number: "000001", title: "Dune", author: "Frank Herbert")
    expect(book.reload).not_to be_borrowed
  end

  it "refuses when the book is not borrowed" do
    post "/books/000001/return"

    expect(response).to have_http_status(:conflict)
    expect(json).to eq(error: "Book 000001 is not borrowed")
  end

  it "returns 404 for an unknown book" do
    post "/books/999999/return"

    expect(response).to have_http_status(:not_found)
  end
end
