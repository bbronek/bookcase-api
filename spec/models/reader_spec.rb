require "rails_helper"

RSpec.describe Reader do
  subject(:reader) { build(:reader) }

  it { is_expected.to validate_presence_of(:full_name) }
  it { is_expected.to validate_presence_of(:card_number) }
  it { is_expected.to validate_uniqueness_of(:card_number).ignoring_case_sensitivity }
  it { is_expected.to validate_presence_of(:email) }

  it "rejects card numbers that are not exactly six digits" do
    %w[ 12345 1234567 12345a ].each do |card_number|
      expect(build(:reader, card_number:)).not_to be_valid
    end
  end

  it "rejects malformed emails" do
    expect(build(:reader, email: "not-an-email")).not_to be_valid
  end

  it "normalizes emails and treats them as unique regardless of case" do
    create(:reader, email: "Ada@Example.com")
    duplicate = build(:reader, email: "  ADA@example.COM ")

    expect(duplicate.email).to eq("ada@example.com")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "cannot be deleted while it has borrowings" do
    reader = create(:borrowing).reader
    expect { reader.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
  end
end
