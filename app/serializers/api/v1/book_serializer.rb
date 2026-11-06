module Api
  module V1
    class BookSerializer < BaseSerializer
      attributes :serial_number, :title, :author, :status
      timestamp :withdrawn_at
      has_one :current_borrowing, serializer: BookBorrowingSerializer

      delegate :status, to: :object
    end
  end
end
