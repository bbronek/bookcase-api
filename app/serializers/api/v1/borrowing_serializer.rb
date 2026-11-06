module Api
  module V1
    class BorrowingSerializer < BookBorrowingSerializer
      one(:book) { attributes :serial_number, :title }
    end
  end
end
