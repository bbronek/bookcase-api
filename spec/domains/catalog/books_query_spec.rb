require "rails_helper"

RSpec.describe Catalog::BooksQuery do
  def query(status: nil, after: nil, limit: 50) = described_class.call(status:, after:, limit:)

  let!(:borrowed) { create(:borrowing, book: create(:book, serial_number: "000002")).book }
  let!(:available) { create(:book, serial_number: "000001") }

  before { create(:book, :withdrawn, serial_number: "000003") }

  it "lists the catalog ordered by serial number" do
    expect(query.records).to eq([ available, borrowed ])
  end

  it "filters by status, including withdrawn books" do
    expect(query(status: "borrowed").records).to eq([ borrowed ])
    expect(query(status: "available").records).to eq([ available ])
    expect(query(status: "withdrawn").records.map(&:serial_number)).to eq(%w[ 000003 ])
  end

  it "pages through the catalog with a keyset cursor" do
    first_page = query(limit: 1)
    second_page = query(limit: 1, after: first_page.next_cursor)

    expect(first_page).to have_attributes(records: [ available ], next_cursor: "000001")
    expect(second_page).to have_attributes(records: [ borrowed ], next_cursor: nil)
  end

  it "loads a page with the same number of queries whatever its size" do
    small_page = count_queries { query.records }
    create_list(:borrowing, 5)

    expect(count_queries { query.records }).to eq(small_page)
  end
end
