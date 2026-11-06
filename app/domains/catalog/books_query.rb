module Catalog
  class BooksQuery
    def self.call(after:, limit:)
      books = Book.in_catalog.includes(current_borrowing: :reader)
      Page.of(books, ordered_by: :serial_number, after:, limit:)
    end
  end
end
