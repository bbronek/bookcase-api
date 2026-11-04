json.partial! "books/book", book: @book
json.borrowings @borrowings, partial: "borrowings/borrowing", as: :borrowing
