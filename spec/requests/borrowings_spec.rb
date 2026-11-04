require "rails_helper"

RSpec.describe "Borrowing a book" do
  let!(:book) { create(:book, serial_number: "000001") }
  let!(:reader) { create(:reader, card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com") }

  it "marks the book as borrowed by the reader for 30 days" do
    travel_to Time.zone.parse("2026-11-04 10:00") do
      post "/books/000001/borrowings", params: { card_number: "100001" }, as: :json
    end

    expect(response).to have_http_status(:created)
    expect(json).to eq(
      id: book.borrowings.first.id, borrowed_at: "2026-11-04T10:00:00.000Z", due_on: "2026-12-04", returned_at: nil,
      reader: { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" },
      book: { serial_number: "000001", title: "Dune", author: "Frank Herbert" }
    )
    expect(book.reload).to be_borrowed
  end

  it "refuses when the book is already borrowed" do
    book.borrow!(create(:reader))

    post "/books/000001/borrowings", params: { card_number: "100001" }, as: :json

    expect(response).to have_http_status(:conflict)
    expect(json).to eq(error: "Book 000001 is already borrowed")
  end

  it "rejects an unknown reader" do
    post "/books/000001/borrowings", params: { card_number: "999999" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json).to eq(error: "Validation failed", details: { card_number: [ "not found" ] })
    expect(book.reload).not_to be_borrowed
  end

  it "requires a card number" do
    post "/books/000001/borrowings", params: {}, as: :json

    expect(response).to have_http_status(:bad_request)
    expect(json[:error]).to match(/card_number/)
  end

  it "returns 404 for an unknown book" do
    post "/books/999999/borrowings", params: { card_number: "100001" }, as: :json

    expect(response).to have_http_status(:not_found)
    expect(json).to eq(error: "Book not found")
  end
end
