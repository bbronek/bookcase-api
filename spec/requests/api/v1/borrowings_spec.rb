require "swagger_helper"

RSpec.describe "API v1 borrowings" do
  let!(:book) { create(:book, serial_number: "000001", title: "Dune", author: "Frank Herbert") }

  def dune = { serial_number: "000001", title: "Dune" }
  def ada = { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" }

  before do
    travel_to Time.zone.parse("2026-11-04 10:00")
    create(:reader, **ada)
  end

  def borrow_dune(card_number: "100001", borrowed_at: nil)
    Circulation::BorrowBook.call(serial_number: "000001", card_number:, borrowed_at:)
  end

  def borrowing_json(borrowing, borrowed_at:, due_on:, returned_at: nil)
    { id: borrowing.id, book: dune, reader: ada, borrowed_at:, due_on:, returned_at: }
  end

  path "/api/v1/books/{serial_number}/borrowings" do
    serial_number_parameter

    let(:serial_number) { "000001" }

    post "Borrow a book" do
      tags "Borrowings"
      operationId "borrowBook"
      description <<~TEXT
        Lends the book to the reader with this card number for 30 days. An already borrowed book answers 409,
        even for the same reader. A withdrawn book cannot be borrowed.
      TEXT
      produces "application/json"
      json_body :NewBorrowing

      let(:body) { { card_number: "100001" } }

      response "201", "Borrowed" do
        schema OpenAPISchemas.ref(:Borrowing)
        header "Location", schema: { type: :string, format: "uri-reference" }, description: "Path of the new borrowing."

        run_test! do
          borrowing = Borrowing.sole
          expect(json).to eq(borrowing_json(borrowing, borrowed_at: "2026-11-04T09:00:00.000Z", due_on: "2026-12-04"))
          expect(response.headers["Location"]).to eq("/api/v1/borrowings/#{borrowing.id}")
        end
      end

      problem_response "404", "No book with this serial number", detail: "Book not found" do
        let(:serial_number) { "999999" }
      end

      problem_response "409", "The book is already borrowed or withdrawn",
                       type: "book-already-borrowed", detail: "Book 000001 is already borrowed" do
        before { borrow_dune(card_number: create(:reader).card_number) }
      end

      problem_response "422", "The card number is missing or matches no reader",
                       type: "validation-failed", detail: "The request has invalid attributes",
                       errors: [ { pointer: "#/card_number", detail: "does not match any reader" } ] do
        let(:body) { { card_number: "999999" } }
      end
    end
  end

  path "/api/v1/borrowings/{id}" do
    parameter name: :id, in: :path, required: true, schema: OpenAPISchemas::UUID

    get "Get a borrowing" do
      tags "Borrowings"
      operationId "getBorrowing"
      produces "application/json"

      response "200", "The borrowing" do
        schema OpenAPISchemas.ref(:Borrowing)

        let(:borrowing) { borrow_dune }
        let(:id) { borrowing.id }

        run_test! do
          expect(json).to eq(borrowing_json(borrowing, borrowed_at: "2026-11-04T09:00:00.000Z", due_on: "2026-12-04"))
        end
      end

      problem_response "404", "No borrowing with this id", detail: "Borrowing not found" do
        let(:id) { "019a0000-0000-7000-8000-000000000000" }
      end
    end
  end

  path "/api/v1/borrowings/{id}/return" do
    parameter name: :id, in: :path, required: true, schema: OpenAPISchemas::UUID

    post "Return a book" do
      tags "Borrowings"
      operationId "returnBook"
      description "Closes the borrowing. Returning an already returned borrowing changes nothing and answers 200 again."
      produces "application/json"

      let(:borrowing) { borrow_dune(borrowed_at: 10.days.ago) }
      let(:id) { borrowing.id }

      response "200", "Returned" do
        schema OpenAPISchemas.ref(:Borrowing)
        header "Content-Location", schema: { type: :string, format: "uri-reference" }, description: "Path of the borrowing."

        run_test! do
          expect(json).to eq(borrowing_json(borrowing, borrowed_at: "2026-10-25T09:00:00.000Z", due_on: "2026-11-24",
                                                       returned_at: "2026-11-04T09:00:00.000Z"))
          expect(book.reload.status).to eq("available")
        end
      end

      problem_response "404", "No borrowing with this id", detail: "Borrowing not found" do
        let(:id) { "019a0000-0000-7000-8000-000000000000" }
      end
    end
  end

  describe "POST /api/v1/books/{serial_number}/borrowings" do
    it "refuses a repeated borrow by the same reader" do
      borrow_dune

      post "/api/v1/books/000001/borrowings", params: { card_number: "100001" }, as: :json

      expect(response).to be_problem(:conflict, type: "book-already-borrowed")
      expect(Borrowing.count).to eq(1)
    end

    it "requires a card number" do
      post "/api/v1/books/000001/borrowings", params: {}, as: :json

      expect(response).to be_problem(:unprocessable_content, type: "validation-failed",
                                                             errors: [ { pointer: "#/card_number", detail: "can't be blank" } ])
    end

    it "refuses to lend a withdrawn book" do
      Catalog::WithdrawBook.call(serial_number: "000001")

      post "/api/v1/books/000001/borrowings", params: { card_number: "100001" }, as: :json

      expect(response).to be_problem(:conflict, type: "book-withdrawn", detail: "Book 000001 was withdrawn from the catalog")
    end
  end

  describe "GET /api/v1/borrowings/{id}" do
    it "renders timestamps in UTC with millisecond precision" do
      borrowing = borrow_dune(borrowed_at: Time.iso8601("2026-10-01T10:00:00.123456+02:00"))
      Circulation::ReturnBook.call(borrowing_id: borrowing.id, returned_at: Time.iso8601("2026-10-20T16:00:00.987654+02:00"))

      get "/api/v1/borrowings/#{borrowing.id}"

      expect(response).to have_http_status(:ok)
      expect(json).to eq(borrowing_json(borrowing, borrowed_at: "2026-10-01T08:00:00.123Z", due_on: "2026-10-31",
                                                 returned_at: "2026-10-20T14:00:00.987Z"))
    end

    it "answers 404 for ids that are not UUIDs" do
      get "/api/v1/borrowings/42"

      expect(response).to be_problem(:not_found, detail: "Borrowing not found")
    end

    it "shows a borrowing with its book and reader preloaded" do
      borrowing = create(:borrowing)

      expect(count_queries { get "/api/v1/borrowings/#{borrowing.id}" }).to eq(3)
    end
  end

  describe "POST /api/v1/borrowings/{id}/return" do
    it "answers a repeated return with the unchanged borrowing" do
      borrowing = borrow_dune(borrowed_at: 10.days.ago)
      post "/api/v1/borrowings/#{borrowing.id}/return"
      first_response = response.body

      travel 1.hour
      post "/api/v1/borrowings/#{borrowing.id}/return"

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(first_response)
    end

    it "never closes a later borrowing when an old return is replayed" do
      first = borrow_dune(borrowed_at: 10.days.ago)
      Circulation::ReturnBook.call(borrowing_id: first.id, returned_at: 5.days.ago)
      second = borrow_dune(card_number: create(:reader).card_number)

      post "/api/v1/borrowings/#{first.id}/return"

      expect(second.reload).not_to be_returned
      expect(book.reload.status).to eq("borrowed")
    end
  end
end
