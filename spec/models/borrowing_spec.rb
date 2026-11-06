require "rails_helper"

RSpec.describe Borrowing do
  describe "validations" do
    subject(:borrowing) { build(:borrowing) }

    it { is_expected.to validate_presence_of(:borrowed_at) }
    it { is_expected.to validate_presence_of(:due_on) }
    it { is_expected.to belong_to(:book).required }
    it { is_expected.to belong_to(:reader).required }

    it "requires a due date after the library-local borrowing date" do
      borrowing = build(:borrowing, borrowed_at: Time.utc(2026, 11, 4, 23, 30), due_on: Date.new(2026, 11, 5))

      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:due_on]).to eq([ "must be greater than 2026-11-05" ])

      borrowing.due_on = Date.new(2026, 11, 6)
      expect(borrowing).to be_valid
    end

    it "rejects a second active borrowing but allows returned history" do
      active = create(:borrowing)
      duplicate = build(:borrowing, book: active.book)
      returned = create(:borrowing, :returned, book: active.book)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:book_id, :taken)).to be(true)
      expect(active).to be_valid
      expect(returned).to be_valid

      returned.returned_at = nil
      expect(returned).not_to be_valid
      expect(returned.errors.of_kind?(:book_id, :taken)).to be(true)
    end

    it "rejects a return before the borrow" do
      borrowing = build(:borrowing, borrowed_at: Time.current, returned_at: 1.minute.ago)

      expect(borrowing).not_to be_valid
      expect(borrowing.errors[:returned_at]).to eq([ "must be greater than or equal to #{borrowing.borrowed_at}" ])
    end
  end

  describe ".due_on_for" do
    it "is the library-local date 30 days after the borrow" do
      expect(described_class.due_on_for(Time.zone.parse("2026-11-04 15:30"))).to eq(Date.new(2026, 12, 4))
    end

    it "counts calendar days, so a daylight saving change never shifts the due date" do
      late_evening_before_the_clocks_change = Time.zone.parse("2027-03-01 23:30")

      expect(described_class.due_on_for(late_evening_before_the_clocks_change)).to eq(Date.new(2027, 3, 31))
      expect(described_class.due_on_for(late_evening_before_the_clocks_change.utc)).to eq(Date.new(2027, 3, 31))
    end

    it "uses the library's time zone, not UTC" do
      just_after_midnight_in_warsaw = Time.utc(2026, 11, 4, 23, 30)

      expect(described_class.due_on_for(just_after_midnight_in_warsaw)).to eq(Date.new(2026, 12, 5))
    end
  end

  describe "database guards, with validations bypassed" do
    let(:book) { create(:book) }
    let(:reader) { create(:reader) }

    def insert(**attributes)
      described_class.insert!({ book_id: book.id, reader_id: reader.id, borrowed_at: 10.days.ago, due_on: 20.days.from_now.to_date,
                                **attributes })
    end

    it "lets a book be borrowed again from the moment it is returned" do
      insert(borrowed_at: 30.days.ago, returned_at: 10.days.ago)

      expect { insert(borrowed_at: 10.days.ago) }.not_to raise_error
    end

    it "allows only one active borrowing per book" do
      insert(borrowed_at: 5.days.ago)

      expect { insert(borrowed_at: 1.day.ago) }.to raise_error(ActiveRecord::RecordNotUnique, /index_borrowings_on_active_book/)
    end

    it "checks due dates in Warsaw even when PostgreSQL uses another session time zone" do
      described_class.connection.execute("SET LOCAL TIME ZONE 'America/New_York'")

      expect { insert(borrowed_at: Time.utc(2026, 11, 4, 23, 30), due_on: Date.new(2026, 11, 5)) }
        .to raise_error(ActiveRecord::CheckViolation, /borrowings_due_after_borrowed/)
    end

    {
      "a return before the borrow" => [ { returned_at: 11.days.ago }, ActiveRecord::CheckViolation, /borrowings_returned_after_borrowed/ ],
      "a due date on or before the borrow date" => [ { due_on: 10.days.ago.to_date }, ActiveRecord::CheckViolation, /borrowings_due_after_borrowed/ ],
      "a missing borrow time" => [ { borrowed_at: nil }, ActiveRecord::NotNullViolation, /borrowed_at/ ],
      "a missing due date" => [ { due_on: nil }, ActiveRecord::NotNullViolation, /due_on/ ],
      "a missing book" => [ { book_id: nil }, ActiveRecord::NotNullViolation, /book_id/ ],
      "a missing reader" => [ { reader_id: nil }, ActiveRecord::NotNullViolation, /reader_id/ ],
      "a book that does not exist" => [ { book_id: SecureRandom.uuid_v7 }, ActiveRecord::InvalidForeignKey, /books/ ],
      "a reader that does not exist" => [ { reader_id: SecureRandom.uuid_v7 }, ActiveRecord::InvalidForeignKey, /readers/ ]
    }.each do |violation, (attributes, error, message)|
      it "rejects #{violation}" do
        expect { insert(**attributes) }.to raise_error(error, message)
      end
    end
  end

  it "is active until it is returned" do
    borrowing = create(:borrowing)

    expect { borrowing.update!(returned_at: Time.current) }
      .to change { described_class.active.exists?(borrowing.id) }.from(true).to(false)
      .and change(borrowing, :returned?).from(false).to(true)
  end

  it "gets a time-ordered UUIDv7 id from PostgreSQL" do
    first, second = create_list(:borrowing, 2)

    expect(first.id).to match(/\A\h{8}-\h{4}-7\h{3}-[89ab]\h{3}-\h{12}\z/)
    expect(first.id).to be < second.id
  end
end
