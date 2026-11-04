require "rails_helper"

RSpec.describe "Books" do
  describe "GET /books" do
    it "lists every book with its availability and current borrower" do
      available = create(:book, serial_number: "000002", title: "Solaris", author: "Stanisław Lem")
      borrowed = create(:book, serial_number: "000001")
      reader = create(:reader, card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com")
      borrowing = borrowed.borrow!(reader, now: Time.zone.parse("2026-11-04 10:00"))

      get "/books"

      expect(response).to have_http_status(:ok)
      expect(json).to eq([
        {
          serial_number: "000001", title: "Dune", author: "Frank Herbert", status: "borrowed",
          current_borrowing: {
            id: borrowing.id, borrowed_at: "2026-11-04T10:00:00.000Z", due_on: "2026-12-04",
            reader: { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" }
          }
        },
        { serial_number: "000002", title: "Solaris", author: "Stanisław Lem", status: "available", current_borrowing: nil }
      ])
      expect(available).to be_present
    end

    it "does not issue one query per book" do
      create_list(:borrowing, 5)
      create_list(:book, 5)

      expect(count_queries { get "/books" }).to eq(3) # books, active borrowings, readers
    end
  end

  describe "GET /books/:serial_number" do
    it "returns the book with its full borrowing history, newest first" do
      book = create(:book, serial_number: "000001")
      first_reader = create(:reader, card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com")
      second_reader = create(:reader, card_number: "100002", full_name: "Alan Turing", email: "alan@example.com")
      book.borrow!(first_reader, now: Time.zone.parse("2026-09-01 10:00"))
      book.return!(now: Time.zone.parse("2026-09-20 16:00"))
      book.borrow!(second_reader, now: Time.zone.parse("2026-11-01 12:00"))

      get "/books/000001"

      expect(response).to have_http_status(:ok)
      expect(json).to include(serial_number: "000001", status: "borrowed")
      expect(json[:current_borrowing]).to include(due_on: "2026-12-01", reader: include(card_number: "100002"))
      expect(json[:borrowings]).to eq([
        {
          id: book.borrowings.first.id, borrowed_at: "2026-11-01T12:00:00.000Z", due_on: "2026-12-01", returned_at: nil,
          reader: { card_number: "100002", full_name: "Alan Turing", email: "alan@example.com" }
        },
        {
          id: book.borrowings.last.id, borrowed_at: "2026-09-01T10:00:00.000Z", due_on: "2026-10-01", returned_at: "2026-09-20T16:00:00.000Z",
          reader: { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" }
        }
      ])
    end

    it "returns 404 for an unknown serial number" do
      get "/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(json).to eq(error: "Book not found")
    end
  end

  describe "POST /books" do
    it "creates a book" do
      post "/books", params: { serial_number: "000001", title: "Dune", author: "Frank Herbert" }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to eq(serial_number: "000001", title: "Dune", author: "Frank Herbert", status: "available", current_borrowing: nil, borrowings: [])
      expect(Book.find_by(serial_number: "000001")).to be_present
    end

    it "rejects invalid attributes" do
      post "/books", params: { serial_number: "12345", title: "", author: "Frank Herbert" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq(error: "Validation failed", details: { serial_number: [ "must be exactly six digits" ], title: [ "can't be blank" ] })
    end

    it "rejects a duplicate serial number" do
      create(:book, serial_number: "000001")

      post "/books", params: { serial_number: "000001", title: "Dune", author: "Frank Herbert" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:details]).to eq(serial_number: [ "has already been taken" ])
    end

    it "rejects a request without book attributes" do
      post "/books", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(json[:error]).to match(/param is missing/)
    end
  end

  describe "DELETE /books/:serial_number" do
    it "deletes a book and its history" do
      book = create(:borrowing, :returned).book

      delete "/books/#{book.serial_number}"

      expect(response).to have_http_status(:no_content)
      expect(Book.exists?(book.id)).to be(false)
      expect(Borrowing.count).to eq(0)
    end

    it "refuses to delete a borrowed book" do
      book = create(:borrowing).book

      delete "/books/#{book.serial_number}"

      expect(response).to have_http_status(:conflict)
      expect(json).to eq(error: "Book #{book.serial_number} cannot be deleted while borrowed")
      expect(Book.exists?(book.id)).to be(true)
    end

    it "returns 404 for an unknown serial number" do
      delete "/books/999999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
