module Circulation
  class BookBorrowed < DomainError::Conflict
    self.problem_type = "book-borrowed"

    def initialize(serial_number)
      super("Book #{serial_number} is currently borrowed")
    end
  end
end
