# == Schema Information
#
# Table name: books
#
#  id            :uuid             not null, primary key
#  author        :string(255)      not null
#  serial_number :string           not null
#  title         :string(255)      not null
#  withdrawn_at  :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_books_on_serial_number  (serial_number) UNIQUE
#
# Check Constraints
#
#  books_author_plain_text         (author::text ~ '[^[:space:]]'::text AND author::text !~ '[[:cntrl:]]'::text)
#  books_author_trimmed            (author::text = btrim(author::text))
#  books_serial_number_six_digits  (serial_number::text ~ '^[0-9]{6}$'::text)
#  books_title_plain_text          (title::text ~ '[^[:space:]]'::text AND title::text !~ '[[:cntrl:]]'::text)
#  books_title_trimmed             (title::text = btrim(title::text))
#
class Book < ApplicationRecord
  has_many :borrowings, -> { newest_first }, dependent: :restrict_with_exception, inverse_of: :book
  has_one :current_borrowing, -> { active }, class_name: "Borrowing", dependent: nil, inverse_of: :book

  normalizes :title, :author, with: ->(text) { text.gsub(SURROUNDING_WHITESPACE, "") }

  validates :serial_number, presence: true, format: SIX_DIGITS_FORMAT, uniqueness: true
  validates :title, :author, presence: true, length: { maximum: 255 }, format: PLAIN_TEXT_FORMAT

  scope :in_catalog, -> { where(withdrawn_at: nil) }

  def to_param = serial_number

  def withdrawn? = withdrawn_at?

  def borrowed? = current_borrowing.present?

  def status
    if withdrawn? then "withdrawn"
    elsif borrowed? then "borrowed"
    else "available"
    end
  end
end
