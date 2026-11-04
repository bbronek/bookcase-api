require "rails_helper"

RSpec.describe Borrowing do
  it "allows only one active borrowing per book at the database level" do
    book = create(:book)
    create(:borrowing, book:)

    expect { build(:borrowing, book:).save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    expect { create(:borrowing, :returned, book:) }.not_to raise_error
  end

  it "rejects a return date earlier than the borrow date at the database level" do
    borrowing = build(:borrowing, borrowed_at: Time.current, returned_at: 1.day.ago)

    expect { borrowing.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /borrowings_returned_after_borrowed/)
  end

  describe ".active" do
    it "returns borrowings that have not been returned" do
      active = create(:borrowing)
      create(:borrowing, :returned)

      expect(described_class.active).to contain_exactly(active)
    end
  end
end
