json.partial! "borrowings/borrowing", borrowing: @borrowing
json.book do
  json.extract! @borrowing.book, :serial_number, :title, :author
end
