module Membership
  class RegisterReader
    class CardNumberTaken < DomainError::Conflict
      self.problem_type = "card-number-taken"

      def initialize(card_number)
        super("Card number #{card_number} belongs to a different reader")
      end
    end

    class EmailTaken < DomainError::Conflict
      self.problem_type = "email-taken"

      def initialize
        super("This email belongs to a different reader")
      end
    end

    def self.call(...) = new(...).call

    def initialize(card_number:, full_name:, email:)
      @reader = Reader.new(card_number:, full_name:, email:)
    end

    def call
      @reader.validate!
      existing_reader_if_identical! || @reader.tap(&:save!)
    rescue ActiveRecord::RecordNotUnique
      existing_reader_if_identical! || raise(EmailTaken)
    end

    private

    def existing_reader_if_identical!
      existing = Reader.find_by(card_number: @reader.card_number)
      return if existing.nil?
      raise CardNumberTaken, existing.card_number unless same_name_and_email?(existing)

      existing
    end

    def same_name_and_email?(reader) = reader.slice(:full_name, :email) == @reader.slice(:full_name, :email)
  end
end
