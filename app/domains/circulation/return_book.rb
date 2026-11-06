module Circulation
  class ReturnBook
    def self.call(...) = new(...).call

    def initialize(borrowing_id:, returned_at: nil)
      @borrowing_id = borrowing_id
      @returned_at = returned_at
    end

    def call
      Borrowing.transaction do
        borrowing = Borrowing.lock.find(@borrowing_id)
        borrowing.update!(returned_at: @returned_at || Time.current) unless borrowing.returned?
        borrowing
      end
    end
  end
end
