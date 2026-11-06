module Circulation
  class BorrowBook
    class CardNumberMissing < DomainError::Invalid
      def initialize
        super("can't be blank", attribute: :card_number)
      end
    end

    class UnknownReader < DomainError::Invalid
      def initialize
        super("does not match any reader", attribute: :card_number)
      end
    end

    def self.call(...) = new(...).call

    def initialize(serial_number:, card_number:, borrowed_at: nil)
      @serial_number = serial_number
      @card_number = card_number
      @borrowed_at = borrowed_at
    end

    def call
      raise CardNumberMissing if @card_number.blank?

      Book.transaction do
        book = Book.lock.find_by!(serial_number: @serial_number)
        raise Catalog::BookWithdrawn, book.serial_number if book.withdrawn?

        reader = Reader.find_by(card_number: @card_number) || raise(UnknownReader)
        raise BookBorrowed, book.serial_number if book.borrowed?

        lend(book, reader)
      end
    end

    private

    def lend(book, reader)
      borrowed_at = @borrowed_at || Time.current
      book.borrowings.create!(reader:, borrowed_at:, due_on: Borrowing.due_on_for(borrowed_at))
    end
  end
end
