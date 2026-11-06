# == Schema Information
#
# Table name: readers
#
#  id          :uuid             not null, primary key
#  card_number :string           not null
#  email       :string(254)      not null
#  full_name   :string(255)      not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_readers_on_card_number  (card_number) UNIQUE
#  index_readers_on_email        (email) UNIQUE
#
# Check Constraints
#
#  readers_card_number_six_digits  (card_number::text ~ '^[0-9]{6}$'::text)
#  readers_email_normalized        (email::text = lower(btrim(email::text)))
#  readers_email_shape             (email::text ~ '^[^@[:space:]]+@[^@[:space:]]+$'::text AND email::text !~ '[[:cntrl:]]'::text)
#  readers_full_name_plain_text    (full_name::text ~ '[^[:space:]]'::text AND full_name::text !~ '[[:cntrl:]]'::text)
#  readers_full_name_trimmed       (full_name::text = btrim(full_name::text))
#
class Reader < ApplicationRecord
  has_many :borrowings, dependent: :restrict_with_exception, inverse_of: :reader

  normalizes :full_name, with: ->(full_name) { full_name.strip }
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :card_number, presence: true, format: SIX_DIGITS_FORMAT, uniqueness: true
  validates :full_name, presence: true, length: { maximum: 255 }, format: PLAIN_TEXT_FORMAT
  validates :email, presence: true, length: { maximum: 254 }, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  def to_param = card_number
end
