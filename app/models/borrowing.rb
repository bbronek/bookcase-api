class Borrowing < ApplicationRecord
  LOAN_PERIOD_DAYS = 30

  belongs_to :book, inverse_of: :borrowings
  belongs_to :reader, inverse_of: :borrowings
  has_many :reminders, dependent: :destroy

  scope :active, -> { where(returned_at: nil) }

  validates :borrowed_at, :due_on, presence: true

  def active? = returned_at.nil?

  def returned? = !active?
end
