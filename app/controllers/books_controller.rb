class BooksController < ApplicationController
  before_action :set_book, only: %i[ show destroy ]

  def index
    @books = Book.includes(current_borrowing: :reader).order(:serial_number)
  end

  def show
    @borrowings = @book.borrowings.includes(:reader)
  end

  def create
    @book = Book.create!(book_params)
    @borrowings = []
    render :show, status: :created
  end

  def destroy
    @book.destroy!
    head :no_content
  end

  private

  def set_book
    @book = Book.find_by!(serial_number: params[:serial_number])
  end

  def book_params
    params.expect(book: %i[ serial_number title author ])
  end
end
