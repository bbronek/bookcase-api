module Api
  module V1
    class BorrowingSerializer < BookBorrowingSerializer
      has_one :book, serializer: BookSummarySerializer
    end
  end
end
