module Catalog
  class WithdrawBook
    class BookBorrowed < DomainError::Conflict
      self.problem_type = "book-borrowed"

      def initialize(serial_number)
        super("Book #{serial_number} is borrowed and cannot be withdrawn until it is returned")
      end
    end

    def self.call(...) = new(...).call

    def initialize(serial_number:)
      @serial_number = serial_number
    end

    def call
      Book.transaction do
        book = Book.lock.find_by!(serial_number: @serial_number)
        raise BookBorrowed, book.serial_number if book.borrowed?

        book.update!(withdrawn_at: Time.current) unless book.withdrawn?
        book
      end
    end
  end
end
