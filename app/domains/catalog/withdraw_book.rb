module Catalog
  class WithdrawBook
    def self.call(...) = new(...).call

    def initialize(serial_number:)
      @serial_number = serial_number
    end

    def call
      Book.transaction do
        book = Book.lock.find_by!(serial_number: @serial_number)
        raise Circulation::BookBorrowed, book.serial_number if book.borrowed?

        book.update!(withdrawn_at: Time.current) unless book.withdrawn?
        book
      end
    end
  end
end
