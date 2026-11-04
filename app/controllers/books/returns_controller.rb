module Books
  class ReturnsController < ApplicationController
    def create
      book = Book.find_by!(serial_number: params[:book_serial_number])
      @borrowing = book.return!
      render "borrowings/show", status: :ok
    end
  end
end
