require "swagger_helper"

RSpec.describe "API v1 books" do
  def dune = { serial_number: "000001", title: "Dune", author: "Frank Herbert" }
  def ada = { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" }
  def alan = { card_number: "100002", full_name: "Alan Turing", email: "alan@example.com" }

  before { travel_to Time.zone.parse("2026-11-04 10:00") }

  def borrow_dune(card_number:, borrowed_at:) = Circulation::BorrowBook.call(serial_number: "000001", card_number:, borrowed_at:)

  path "/api/v1/books" do
    get "List books" do
      tags "Books"
      operationId "listBooks"
      description "Books in the catalog ordered by serial number, with each book's status and current borrowing. " \
                  "`?status=withdrawn` lists withdrawn books instead."
      produces "application/json"
      parameter name: :status, getter: :status_filter, in: :query, required: false,
                schema: { type: :string, enum: Book::STATUSES }, description: "Only books in this status."
      page_parameters

      before do
        create(:reader, **ada)
        create(:book, **dune)
        create(:book, serial_number: "000002", title: "Solaris", author: "Stanisław Lem")
        borrow_dune(card_number: "100001", borrowed_at: 2.days.ago)
      end

      response "200", "A page of books" do
        schema type: :array, items: OpenAPISchemas.ref(:Book)
        header "Link", schema: { type: :string }, required: false, description: "`<url>; rel=\"next\"` when there is a next page."

        let(:limit) { 1 }

        run_test! do
          current_borrowing = { id: Borrowing.sole.id, reader: ada, borrowed_at: "2026-11-02T09:00:00.000Z", due_on: "2026-12-02", returned_at: nil }

          expect(json).to eq([ dune.merge(status: "borrowed", withdrawn_at: nil, current_borrowing:) ])
          expect(response.headers["Link"]).to eq('</api/v1/books?after=000001&limit=1>; rel="next"')
        end
      end

      problem_response "400", "Unknown status or invalid page parameters",
                       detail: "status must be one of: available, borrowed, withdrawn" do
        let(:status_filter) { "lost" }
      end
    end

    post "Add a book" do
      tags "Books"
      operationId "addBook"
      description "Adds a book to the catalog. Repeating the request with the same attributes answers 200 with the existing book."
      produces "application/json"
      json_body :NewBook

      let(:body) { dune }

      response "201", "Added" do
        schema OpenAPISchemas.ref(:Book)
        header "Location", schema: { type: :string, format: "uri-reference" }, description: "Path of the new book."

        run_test! do
          expect(json).to eq(dune.merge(status: "available", withdrawn_at: nil, current_borrowing: nil))
          expect(response.headers["Location"]).to eq("/api/v1/books/000001")
        end
      end

      response "200", "Already in the catalog with the same attributes" do
        schema OpenAPISchemas.ref(:Book)
        header "Content-Location", schema: { type: :string, format: "uri-reference" }, description: "Path of the existing book."

        before { create(:book, **dune) }

        run_test! do
          expect(json).to eq(dune.merge(status: "available", withdrawn_at: nil, current_borrowing: nil))
          expect(response.headers["Content-Location"]).to eq("/api/v1/books/000001")
        end
      end

      problem_response "409", "The serial number belongs to a different book, or to a withdrawn one",
                       type: "serial-number-taken", detail: "Serial number 000001 belongs to a different book in the catalog" do
        before { create(:book, **dune, title: "Dune Messiah") }
      end

      problem_response "422", "Invalid attributes",
                       type: "validation-failed", detail: "The request has invalid attributes",
                       errors: [ { pointer: "#/author", detail: "must be a string" } ] do
        let(:body) { { serial_number: "12345", title: "", author: 42 } }
      end
    end
  end

  path "/api/v1/books/{serial_number}" do
    serial_number_parameter

    let(:serial_number) { "000001" }

    get "Get a book with its borrowing history" do
      tags "Books"
      operationId "getBook"
      description "Withdrawn books stay readable, with their history."
      produces "application/json"

      response "200", "The book and its full history, newest first" do
        schema OpenAPISchemas.ref(:BookDetail)

        before do
          create(:book, **dune)
          create(:reader, **ada)
          create(:reader, **alan)
          returned = borrow_dune(card_number: "100001", borrowed_at: Time.zone.parse("2026-09-01 10:00"))
          Circulation::ReturnBook.call(borrowing_id: returned.id, returned_at: Time.zone.parse("2026-09-20 16:00"))
          borrow_dune(card_number: "100002", borrowed_at: Time.zone.parse("2026-11-01 12:00"))
        end

        run_test! do
          returned, current = Borrowing.order(:borrowed_at)
          current_borrowing = { id: current.id, reader: alan, borrowed_at: "2026-11-01T11:00:00.000Z", due_on: "2026-12-01", returned_at: nil }
          returned_borrowing = { id: returned.id, reader: ada, borrowed_at: "2026-09-01T08:00:00.000Z", due_on: "2026-10-01",
                                 returned_at: "2026-09-20T14:00:00.000Z" }

          expect(json).to eq(dune.merge(status: "borrowed", withdrawn_at: nil, current_borrowing:,
                                        borrowings: [ current_borrowing, returned_borrowing ]))
        end
      end

      problem_response "404", "No book with this serial number", detail: "Book not found"
    end

    delete "Withdraw a book" do
      tags "Books"
      operationId "withdrawBook"
      description "Takes the book out of the catalog. Its history is kept and its serial number is never reused. " \
                  "Withdrawing a withdrawn book answers 204 again."
      produces "application/json"

      response "204", "Withdrawn" do
        before { create(:borrowing, :returned, book: create(:book, **dune)) }

        run_test! do
          expect(response.body).to be_empty
          expect(Book.find_by!(serial_number: "000001")).to be_withdrawn
          expect(Borrowing.count).to eq(1)
        end
      end

      problem_response "404", "No book with this serial number", detail: "Book not found"

      problem_response "409", "The book is borrowed",
                       type: "book-borrowed", detail: "Book 000001 is borrowed and cannot be withdrawn until it is returned" do
        before { create(:borrowing, book: create(:book, **dune)) }
      end
    end
  end

  describe "GET /api/v1/books" do
    it "keeps the status filter in the next page link" do
      create(:book, serial_number: "000001")
      create(:book, serial_number: "000002")

      get "/api/v1/books", params: { status: "available", limit: 1 }

      expect(json.pluck(:serial_number)).to eq(%w[ 000001 ])
      expect(response.headers["Link"]).to eq('</api/v1/books?after=000001&limit=1&status=available>; rel="next"')

      get "/api/v1/books", params: { status: "available", limit: 1, after: "000001" }

      expect(json.pluck(:serial_number)).to eq(%w[ 000002 ])
      expect(response.headers["Link"]).to be_nil
    end

    it "pages 50 books at a time by default and at most 100" do
      Book.insert_all!(Array.new(101) { |index| { serial_number: format("%06d", index + 1), title: "Book", author: "Author" } })

      get "/api/v1/books"
      expect(json.size).to eq(50)

      get "/api/v1/books", params: { limit: 100 }
      expect(json.size).to eq(100)
      expect(response.headers["Link"]).to eq('</api/v1/books?after=000100&limit=100>; rel="next"')
    end

    it "rejects invalid page sizes and cursors" do
      [ { limit: "0" }, { limit: "101" }, { limit: "ten" }, { limit: "" }, { limit: "+5" }, { limit: "010" }, { after: "zzz" } ].each do |params|
        get "/api/v1/books", params: params

        expect(response).to be_problem(:bad_request), params.inspect
      end
    end

    it "rejects a query parameter given more than once" do
      get "/api/v1/books", params: { after: [ "000001", "000002" ] }

      expect(response).to be_problem(:bad_request, detail: "after must be a single value")
    end

    it "lists books with the same number of queries however many there are" do
      create(:borrowing)
      one_book = count_queries { get "/api/v1/books" }
      create_list(:borrowing, 5)

      expect(count_queries { get "/api/v1/books" }).to eq(one_book)
    end
  end

  describe "POST /api/v1/books" do
    it "accepts JSON with a charset parameter" do
      post "/api/v1/books", params: dune.to_json, headers: { "Content-Type" => "application/json; charset=utf-8" }

      expect(response).to have_http_status(:created)
    end

    it "rejects a body that is not a JSON object" do
      post "/api/v1/books", params: "[1]", headers: { "Content-Type" => "application/json" }

      expect(response).to be_problem(:bad_request, detail: "Request body must be a JSON object")
    end

    it "lists the validation failure of every attribute" do
      post "/api/v1/books", params: { serial_number: "12345", title: " ", author: "A\u0007" }, as: :json

      expect(json[:errors]).to eq([
        { pointer: "#/serial_number", detail: "must be exactly six digits" },
        { pointer: "#/title", detail: "can't be blank" },
        { pointer: "#/author", detail: "must not contain control characters" }
      ])
    end
  end

  describe "GET /api/v1/books/{serial_number}" do
    it "shows a book with the same number of queries however long its history is" do
      book = create(:borrowing, :returned).book
      short_history = count_queries { get "/api/v1/books/#{book.serial_number}" }
      [ 3, 6, 9 ].each { |months| create(:borrowing, :returned, book:, borrowed_at: months.months.ago) }

      expect(count_queries { get "/api/v1/books/#{book.serial_number}" }).to eq(short_history)
    end
  end

  describe "DELETE /api/v1/books/{serial_number}" do
    it "keeps a withdrawn book readable, refuses to lend it and never reuses its serial number" do
      create(:borrowing, :returned, book: create(:book, **dune))

      2.times { delete "/api/v1/books/000001" }
      expect(response).to have_http_status(:no_content)

      get "/api/v1/books/000001"
      expect(json).to include(status: "withdrawn", withdrawn_at: "2026-11-04T09:00:00.000Z", current_borrowing: nil)
      expect(json[:borrowings].size).to eq(1)

      post "/api/v1/books/000001/borrowings", params: { card_number: create(:reader).card_number }, as: :json
      expect(response).to be_problem(:conflict, type: "book-withdrawn", detail: "Book 000001 was withdrawn from the catalog")

      post "/api/v1/books", params: dune, as: :json
      expect(response).to be_problem(:conflict, type: "book-withdrawn")
    end
  end
end
