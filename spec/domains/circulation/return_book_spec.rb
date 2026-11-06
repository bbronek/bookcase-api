require "rails_helper"

RSpec.describe Circulation::ReturnBook do
  let(:borrowing) { create(:borrowing, borrowed_at: 10.days.ago) }

  it "closes the borrowing" do
    freeze_time do
      expect(described_class.call(borrowing_id: borrowing.id)).to have_attributes(id: borrowing.id, returned_at: Time.current)
    end
    expect(borrowing.book.reload.status).to eq("available")
  end

  it "is idempotent: returning again changes nothing" do
    returned_at = described_class.call(borrowing_id: borrowing.id, returned_at: 1.day.ago).returned_at

    expect(described_class.call(borrowing_id: borrowing.id).returned_at).to eq(returned_at)
  end

  it "does not find unknown borrowings" do
    expect { described_class.call(borrowing_id: SecureRandom.uuid_v7) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end
