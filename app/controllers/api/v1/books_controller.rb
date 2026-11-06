module Api
  module V1
    class BooksController < BaseController
      include KeysetPagination

      def index
        page = Catalog::BooksQuery.call(**page_params)
        render_page page, with: BookSerializer
      end

      def show
        book = Book.includes(current_borrowing: :reader, borrowings: :reader)
          .find_by!(serial_number: path_parameter(:serial_number))
        render_resource book, with: BookDetailSerializer
      end

      def create
        book = Catalog::AddBook.call(**body_attributes(:serial_number, :title, :author))
        render_created book, with: BookSerializer, location: api_v1_book_path(book)
      end

      def destroy
        Catalog::WithdrawBook.call(serial_number: path_parameter(:serial_number))
        head :no_content
      end
    end
  end
end
