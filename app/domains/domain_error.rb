class DomainError < StandardError
  class_attribute :problem_type, instance_writer: false

  class Conflict < DomainError; end

  class Invalid < DomainError
    self.problem_type = "validation-failed"

    attr_reader :attribute

    def initialize(message, attribute:)
      super(message)
      @attribute = attribute
    end
  end
end
