class Book < ApplicationRecord
  SERIAL_NUMBER_FORMAT = /\A\d{6}\z/

  # Raised when a borrow/return/delete is requested in a state that does not allow it (HTTP 409).
  class InvalidTransition < StandardError; end

  has_many :borrowings, -> { order(borrowed_at: :desc) }, dependent: :destroy, inverse_of: :book
  has_one :current_borrowing, -> { active }, class_name: "Borrowing", inverse_of: :book

  # prepend: true so this runs before the has_many dependent: :destroy callback deletes the history.
  before_destroy :prevent_destroy_while_borrowed, prepend: true

  validates :serial_number, presence: true, uniqueness: true,
                            format: { with: SERIAL_NUMBER_FORMAT, message: "must be exactly six digits" }
  validates :title, :author, presence: true

  def to_param = serial_number

  def borrowed? = current_borrowing.present?

  def status = borrowed? ? "borrowed" : "available"

  # Creates the active borrowing for +reader+. The partial unique index on borrowings is the real guard;
  # the in-memory check only gives a friendly error without a round-trip in the common case.
  def borrow!(reader, now: Time.current)
    raise InvalidTransition, "Book #{serial_number} is already borrowed" if borrowed?

    borrowings.create!(reader:, borrowed_at: now, due_on: now.to_date + Borrowing::LOAN_PERIOD_DAYS)
               .tap { reset_current_borrowing }
  rescue ActiveRecord::RecordNotUnique
    raise InvalidTransition, "Book #{serial_number} is already borrowed"
  end

  def return!(now: Time.current)
    raise InvalidTransition, "Book #{serial_number} is not borrowed" unless borrowed?

    current_borrowing.tap { |borrowing| borrowing.update!(returned_at: now) }
                     .tap { reset_current_borrowing }
  end

  private

  def prevent_destroy_while_borrowed
    return unless borrowed?

    errors.add(:base, "Book #{serial_number} cannot be deleted while borrowed")
    throw :abort
  end
end
