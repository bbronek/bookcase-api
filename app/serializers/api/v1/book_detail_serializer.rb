module Api
  module V1
    class BookDetailSerializer < BookSerializer
      many :borrowings, resource: BookBorrowingSerializer
    end
  end
end
