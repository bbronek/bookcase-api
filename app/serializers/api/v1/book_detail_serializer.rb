module Api
  module V1
    class BookDetailSerializer < BookSerializer
      has_many :borrowings, serializer: BookBorrowingSerializer
    end
  end
end
