module Api
  module V1
    class BookBorrowingSerializer < BaseSerializer
      attributes :id
      has_one :reader, serializer: ReaderSerializer
      timestamp :borrowed_at
      attributes :due_on
      timestamp :returned_at
    end
  end
end
