module Api
  module V1
    class BookBorrowingSerializer < BaseSerializer
      attributes :id
      has_one :reader, serializer: ReaderSerializer
      timestamp :borrowed_at
      attributes :due_on
      def due_on = object.due_on.iso8601
      timestamp :returned_at
    end
  end
end
