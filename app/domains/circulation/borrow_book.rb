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
      Book.transaction do
        book = Book.lock.find_by!(serial_number: @serial_number)
        raise Catalog::BookWithdrawn, book.serial_number if book.withdrawn?
        raise BookBorrowed, book.serial_number if book.borrowed?

        lend(book, find_reader!)
      end
    end

    private

    def find_reader!
      raise CardNumberMissing if @card_number.blank?

      Reader.find_by(card_number: @card_number) || raise(UnknownReader)
    end

    def lend(book, reader)
      borrowed_at = @borrowed_at || Time.current
      book.borrowings.create!(reader:, borrowed_at:, due_on: Borrowing.due_on_for(borrowed_at))
    end
  end
end
