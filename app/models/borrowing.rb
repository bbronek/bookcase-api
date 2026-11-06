# == Schema Information
#
# Table name: borrowings
#
#  id          :uuid             not null, primary key
#  borrowed_at :datetime         not null
#  due_on      :date             not null
#  returned_at :datetime
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  book_id     :uuid             not null
#  reader_id   :uuid             not null
#
# Indexes
#
#  index_borrowings_on_active_book    (book_id) UNIQUE WHERE (returned_at IS NULL)
#  index_borrowings_on_book_history   (book_id,borrowed_at DESC,id DESC)
#  index_borrowings_on_due_on_active  (due_on) WHERE (returned_at IS NULL)
#  index_borrowings_on_reader_id      (reader_id)
#
# Foreign Keys
#
#  fk_rails_...  (book_id => books.id)
#  fk_rails_...  (reader_id => readers.id)
#
# Check Constraints
#
#  borrowings_due_after_borrowed       (due_on > (borrowed_at AT TIME ZONE 'Europe/Warsaw'::text)::date)
#  borrowings_returned_after_borrowed  (returned_at IS NULL OR returned_at >= borrowed_at)
#
class Borrowing < ApplicationRecord
  PERIOD = 30.days

  belongs_to :book, inverse_of: :borrowings
  belongs_to :reader, inverse_of: :borrowings
  has_many :reminders, dependent: :restrict_with_exception, inverse_of: :borrowing

  validates :borrowed_at, :due_on, presence: true
  validates :returned_at, comparison: { greater_than_or_equal_to: :borrowed_at }, allow_nil: true

  scope :active, -> { where(returned_at: nil) }
  scope :newest_first, -> { order(borrowed_at: :desc, id: :desc) }

  def self.due_on_for(borrowed_at) = borrowed_at.in_time_zone.to_date + PERIOD

  def returned? = returned_at?
end
