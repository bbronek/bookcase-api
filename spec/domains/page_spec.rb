require "rails_helper"

RSpec.describe Page do
  before { %w[ 000003 000001 000002 ].each { |serial_number| create(:book, serial_number:) } }

  def page(after: nil, limit: 2) = described_class.of(Book.all, ordered_by: :serial_number, after:, limit:)

  it "orders the records and points the cursor at the last one when more follow" do
    expect(page).to have_attributes(records: Book.order(:serial_number).first(2), next_cursor: "000002")
  end

  it "continues after the cursor" do
    expect(page(after: "000002").records.map(&:serial_number)).to eq(%w[ 000003 ])
  end

  it "has no cursor when the page holds exactly the last records" do
    expect(page(limit: 3).next_cursor).to be_nil
    expect(page(after: "000001").next_cursor).to be_nil
  end
end
