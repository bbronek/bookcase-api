module Api
  module V1
    class BookSerializer < BaseSerializer
      attributes :serial_number, :title, :author, :status
      timestamp :withdrawn_at
      one :current_borrowing, resource: BookBorrowingSerializer
    end
  end
end
