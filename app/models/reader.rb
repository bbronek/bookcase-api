class Reader < ApplicationRecord
  CARD_NUMBER_FORMAT = /\A\d{6}\z/

  has_many :borrowings, dependent: :restrict_with_exception, inverse_of: :reader

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :card_number, presence: true, uniqueness: true,
                          format: { with: CARD_NUMBER_FORMAT, message: "must be exactly six digits" }
  validates :full_name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def to_param = card_number
end
