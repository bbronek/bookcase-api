module Api
  module V1
    class BorrowingsController < BaseController
      def show
        borrowing = Borrowing.includes(:book, :reader).find(path_parameter(:id))
        render_resource borrowing, with: BorrowingSerializer
      end

      def create
        borrowing = Circulation::BorrowBook.call(
          serial_number: path_parameter(:book_serial_number), **body_attributes(:card_number)
        )
        render_created_or_existing borrowing, with: BorrowingSerializer, location: api_v1_borrowing_path(borrowing)
      end
    end
  end
end
