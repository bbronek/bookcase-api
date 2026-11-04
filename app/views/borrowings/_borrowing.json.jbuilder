json.extract! borrowing, :id, :borrowed_at, :due_on, :returned_at
json.reader borrowing.reader, partial: "readers/reader", as: :reader
