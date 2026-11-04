json.extract! book, :serial_number, :title, :author, :status

if book.borrowed?
  json.current_borrowing do
    json.extract! book.current_borrowing, :id, :borrowed_at, :due_on
    json.reader book.current_borrowing.reader, partial: "readers/reader", as: :reader
  end
else
  json.current_borrowing nil
end
