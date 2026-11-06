module Catalog
  class AddBook
    class SerialNumberTaken < DomainError::Conflict
      self.problem_type = "serial-number-taken"

      def initialize(serial_number)
        super("Serial number #{serial_number} is already registered")
      end
    end

    def self.call(...) = new(...).call

    def initialize(serial_number:, title:, author:)
      @book = Book.new(serial_number:, title:, author:)
    end

    def call
      Book.transaction(requires_new: true) { @book.tap(&:save!) }
    rescue ActiveRecord::RecordNotUnique
      raise SerialNumberTaken, @book.serial_number
    end
  end
end
