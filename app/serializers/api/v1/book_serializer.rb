module Api
  module V1
    class BookSerializer < BaseSerializer
      attributes :serial_number, :title, :author, :status
      delegate :status, to: :object
      timestamp :withdrawn_at
      has_one :current_borrowing, serializer: BookBorrowingSerializer
    end
  end
end
