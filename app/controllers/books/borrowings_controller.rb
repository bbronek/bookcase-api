module Books
  class BorrowingsController < ApplicationController
    def create
      book = Book.find_by!(serial_number: params[:book_serial_number])
      reader = Reader.find_by(card_number: params.expect(:card_number))
      return render_error :unprocessable_content, "Validation failed", details: { card_number: [ "not found" ] } unless reader

      @borrowing = book.borrow!(reader)
      render "borrowings/show", status: :created
    end
  end
end
