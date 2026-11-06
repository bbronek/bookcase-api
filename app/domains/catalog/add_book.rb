module Catalog
  class AddBook
    class SerialNumberTaken < DomainError::Conflict
      self.problem_type = "serial-number-taken"

      def initialize(serial_number)
        super("Serial number #{serial_number} belongs to a different book in the catalog")
      end
    end

    def self.call(...) = new(...).call

    def initialize(serial_number:, title:, author:)
      @book = Book.new(serial_number:, title:, author:)
    end

    def call
      @book.validate!
      existing_book_if_identical! || @book.tap(&:save!)
    rescue ActiveRecord::RecordNotUnique
      existing_book_if_identical! || raise
    end

    private

    def existing_book_if_identical!
      existing = Book.find_by(serial_number: @book.serial_number)
      return if existing.nil?
      raise BookWithdrawn, existing.serial_number if existing.withdrawn?
      raise SerialNumberTaken, existing.serial_number unless same_title_and_author?(existing)

      existing
    end

    def same_title_and_author?(book) = book.slice(:title, :author) == @book.slice(:title, :author)
  end
end
