require "rails_helper"

RSpec.describe Membership::ReadersQuery do
  it "pages through readers ordered by card number" do
    second = create(:reader, card_number: "100002")
    first = create(:reader, card_number: "100001")

    first_page = described_class.call(after: nil, limit: 1)

    expect(first_page).to have_attributes(records: [ first ], next_cursor: "100001")
    expect(described_class.call(after: first_page.next_cursor, limit: 1)).to have_attributes(records: [ second ], next_cursor: nil)
  end
end
