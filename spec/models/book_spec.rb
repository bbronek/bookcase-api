require "rails_helper"

RSpec.describe Book do
  describe "validations" do
    subject(:book) { build(:book) }

    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:author) }
    it { is_expected.to validate_length_of(:title).is_at_most(255) }
    it { is_expected.to validate_length_of(:author).is_at_most(255) }

    it "accepts six-digit serial numbers, leading zeros included" do
      expect(build(:book, serial_number: "000042")).to be_valid
    end

    it { is_expected.to validate_presence_of(:serial_number) }

    it "rejects a serial number reserved by a withdrawn book without rejecting that book itself" do
      existing = create(:book, :withdrawn)
      duplicate = build(:book, serial_number: existing.serial_number)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.of_kind?(:serial_number, :taken)).to be(true)
      expect(existing).to be_valid
    end

    it "rejects serial numbers that are not exactly six ASCII digits" do
      [ "12345", "1234567", "12345a", "١٢٣٤٥٦" ].each do |serial_number|
        book = build(:book, serial_number:)

        expect(book).not_to be_valid
        expect(book.errors[:serial_number]).to eq([ "must be exactly six digits" ])
      end
    end

    it "accepts the joiners and direction marks that real titles and names need" do
      expect(build(:book, title: "Family \u{1F468}\u200D\u{1F469}\u200D\u{1F467}", author: "خانه\u200Cها \u200Fעברית")).to be_valid
    end

    it "rejects control characters in the title and author" do
      [ "Dune\u0007", "Du\nne" ].each do |title|
        book = build(:book, title:, author: "Frank\u0000Herbert")

        expect(book).not_to be_valid
        plain_text = "must not contain control characters"
        expect(book.errors.to_hash).to eq(title: [ plain_text ], author: [ plain_text ])
      end
    end
  end

  describe "normalization" do
    it "trims the title and author without changing their internal spacing" do
      book = described_class.new(title: "  The   Dispossessed ", author: " Ursula K. Le Guin ")

      expect(book).to have_attributes(title: "The   Dispossessed", author: "Ursula K. Le Guin")
    end
  end

  describe "database guards, with validations bypassed" do
    let(:row) { { serial_number: "000001", title: "Dune", author: "Frank Herbert" } }

    {
      "title" => [ "' Dune '", /books_title_trimmed/ ],
      "author" => [ "'Frank Herbert '", /books_author_trimmed/ ]
    }.each do |column, (untrimmed, constraint)|
      it "stores only a trimmed #{column}, so a write that skips normalization fails" do
        book = create(:book)

        expect { described_class.where(id: book.id).update_all("#{column} = #{untrimmed}") }
          .to raise_error(ActiveRecord::CheckViolation, constraint)
      end
    end

    it "never reuses a serial number, not even after withdrawal" do
      described_class.insert!(row.merge(withdrawn_at: 1.day.ago))

      expect { described_class.insert!(row) }.to raise_error(ActiveRecord::RecordNotUnique, /index_books_on_serial_number/)
    end

    {
      "a serial number that is not six digits" => [ { serial_number: "12345a" }, ActiveRecord::CheckViolation, /books_serial_number_six_digits/ ],
      "a missing serial number" => [ { serial_number: nil }, ActiveRecord::NotNullViolation, /serial_number/ ],
      "a missing title" => [ { title: nil }, ActiveRecord::NotNullViolation, /title/ ],
      "a blank title" => [ { title: "   " }, ActiveRecord::CheckViolation, /books_title_plain_text/ ],
      "control characters in the title" => [ { title: "Dune\u0007" }, ActiveRecord::CheckViolation, /books_title_plain_text/ ],
      "a title longer than 255 characters" => [ { title: "x" * 256 }, ActiveRecord::ValueTooLong, /character varying\(255\)/ ],
      "a missing author" => [ { author: nil }, ActiveRecord::NotNullViolation, /author/ ],
      "a blank author" => [ { author: " " }, ActiveRecord::CheckViolation, /books_author_plain_text/ ],
      "control characters in the author" => [ { author: "Frank\u0007Herbert" }, ActiveRecord::CheckViolation, /books_author_plain_text/ ],
      "an author longer than 255 characters" => [ { author: "x" * 256 }, ActiveRecord::ValueTooLong, /character varying\(255\)/ ]
    }.each do |violation, (attributes, error, message)|
      it "rejects #{violation}" do
        expect { described_class.insert!(row.merge(attributes)) }.to raise_error(error, message)
      end
    end
  end

  describe ".with_status" do
    it "selects books by their derived status" do
      available = create(:book)
      borrowed = create(:borrowing).book
      returned = create(:borrowing, :returned).book
      withdrawn = create(:book, :withdrawn)

      expect(described_class.with_status(nil)).to contain_exactly(available, borrowed, returned)
      expect(described_class.with_status("available")).to contain_exactly(available, returned)
      expect(described_class.with_status("borrowed")).to contain_exactly(borrowed)
      expect(described_class.with_status("withdrawn")).to contain_exactly(withdrawn)
    end
  end

  describe "#status" do
    it "is borrowed while a borrowing is active and available otherwise" do
      book = create(:book)
      expect(book.status).to eq("available")

      borrowing = create(:borrowing, book:)
      expect(book.reload.status).to eq("borrowed")

      borrowing.update!(returned_at: Time.current)
      expect(book.reload.status).to eq("available")

      book.update!(withdrawn_at: Time.current)
      expect(book.status).to eq("withdrawn")
    end
  end

  describe "#borrowings" do
    it "lists the history newest first" do
      book = create(:book)
      older = create(:borrowing, :returned, book:)
      newer = create(:borrowing, book:)

      expect(book.borrowings).to eq([ newer, older ])
    end
  end

  it "is addressed by its serial number" do
    expect(build(:book, serial_number: "000042").to_param).to eq("000042")
  end
end
