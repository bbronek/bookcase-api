module Api
  module V1
    class BookBorrowingSerializer < BaseSerializer
      attributes :id
      one(:reader) { attributes :card_number, :full_name }
      timestamp :borrowed_at
      attributes :due_on
      timestamp :returned_at
    end
  end
end
