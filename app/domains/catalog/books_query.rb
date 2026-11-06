module Catalog
  class BooksQuery
    def self.call(status:, after:, limit:)
      books = Book.with_status(status).includes(current_borrowing: :reader)
      Page.of(books, ordered_by: :serial_number, after:, limit:)
    end
  end
end
