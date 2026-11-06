module Catalog
  class BookWithdrawn < DomainError::Conflict
    self.problem_type = "book-withdrawn"

    def initialize(serial_number)
      super("Book #{serial_number} was withdrawn from the catalog")
    end
  end
end
