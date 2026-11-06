module Membership
  class RegisterReader
    class CardNumberTaken < DomainError::Conflict
      self.problem_type = "card-number-taken"

      def initialize(card_number)
        super("Card number #{card_number} is already registered")
      end
    end

    class EmailTaken < DomainError::Conflict
      self.problem_type = "email-taken"

      def initialize
        super("This email is already registered")
      end
    end

    def self.call(...) = new(...).call

    def initialize(card_number:, full_name:, email:)
      @reader = Reader.new(card_number:, full_name:, email:)
    end

    def call
      Reader.transaction(requires_new: true) { @reader.tap(&:save!) }
    rescue ActiveRecord::RecordInvalid => error
      raise unless error.record.errors.all? { |validation| validation.type == :taken }

      raise_identifier_taken
    rescue ActiveRecord::RecordNotUnique
      raise_identifier_taken
    end

    private

    def raise_identifier_taken
      raise CardNumberTaken, @reader.card_number if Reader.exists?(card_number: @reader.card_number)

      raise EmailTaken
    end
  end
end
