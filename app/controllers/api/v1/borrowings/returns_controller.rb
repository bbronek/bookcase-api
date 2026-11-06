module Api
  module V1
    module Borrowings
      class ReturnsController < BaseController
        def create
          borrowing = Circulation::ReturnBook.call(borrowing_id: path_parameter(:borrowing_id))
          response.set_header("Content-Location", api_v1_borrowing_path(borrowing))
          render_resource borrowing, with: BorrowingSerializer
        end
      end
    end
  end
end
