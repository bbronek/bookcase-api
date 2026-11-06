require "rails_helper"

RSpec.describe Reader do
  describe "validations" do
    subject(:reader) { build(:reader) }

    it { is_expected.to validate_presence_of(:full_name) }
    it { is_expected.to validate_length_of(:full_name).is_at_most(255) }
    it { is_expected.to validate_length_of(:email).is_at_most(254) }

    it { is_expected.to validate_presence_of(:card_number) }
    it { is_expected.to validate_presence_of(:email) }

    it "rejects duplicate card numbers and normalized emails without rejecting the original reader" do
      existing = create(:reader)
      duplicate = build(:reader, card_number: existing.card_number, email: " #{existing.email.upcase} ")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors.to_hash).to eq(card_number: [ "has already been taken" ], email: [ "has already been taken" ])
      expect(existing).to be_valid
    end

    it "rejects card numbers that are not exactly six digits" do
      [ "12345", "1234567", "12345a" ].each do |card_number|
        reader = build(:reader, card_number:)

        expect(reader).not_to be_valid
        expect(reader.errors[:card_number]).to eq([ "must be exactly six digits" ])
      end
    end

    it "accepts ordinary and internationalized email addresses" do
      [ "ada@example.com", "ada.lovelace+books@mail.example.co.uk", "o'brien@example.org", "ada@example.xn--p1ai" ].each do |email|
        expect(build(:reader, email:)).to be_valid
      end
    end

    it "rejects malformed emails" do
      [ "not-an-email", "two@@example.com", "ada name@example.com", "ada@-example.com" ].each do |email|
        expect(build(:reader, email:)).not_to be_valid, email
      end
    end

    it "rejects control characters in the full name" do
      reader = build(:reader, full_name: "Eve\u0007")

      expect(reader).not_to be_valid
      expect(reader.errors[:full_name]).to eq([ "must not contain control characters" ])
    end
  end

  describe "normalization" do
    it "trims the name and trims and lower-cases the email" do
      reader = described_class.new(full_name: " Ada   Lovelace ", email: "  Ada@Example.COM ")

      expect(reader).to have_attributes(full_name: "Ada   Lovelace", email: "ada@example.com")
    end
  end

  describe "database guards, with validations bypassed" do
    let(:row) { { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" } }

    it "keeps card numbers unique" do
      described_class.insert!(row)

      expect { described_class.insert!(row.merge(email: "other@example.com")) }
        .to raise_error(ActiveRecord::RecordNotUnique, /index_readers_on_card_number/)
    end

    it "keeps emails unique" do
      described_class.insert!(row)

      expect { described_class.insert!(row.merge(card_number: "100002")) }.to raise_error(ActiveRecord::RecordNotUnique, /index_readers_on_email/)
    end

    it "stores only normalized emails, so uniqueness is case-insensitive" do
      reader = create(:reader)

      expect { described_class.where(id: reader.id).update_all("email = 'Ada@Example.com'") }
        .to raise_error(ActiveRecord::CheckViolation, /readers_email_normalized/)
    end

    {
      "a card number that is not six digits" => [ { card_number: "1" }, ActiveRecord::CheckViolation, /readers_card_number_six_digits/ ],
      "a missing card number" => [ { card_number: nil }, ActiveRecord::NotNullViolation, /card_number/ ],
      "a missing full name" => [ { full_name: nil }, ActiveRecord::NotNullViolation, /full_name/ ],
      "a blank full name" => [ { full_name: " " }, ActiveRecord::CheckViolation, /readers_full_name_plain_text/ ],
      "control characters in the full name" => [ { full_name: "Eve\u0007" }, ActiveRecord::CheckViolation, /readers_full_name_plain_text/ ],
      "a full name longer than 255 characters" => [ { full_name: "x" * 256 }, ActiveRecord::ValueTooLong, /character varying\(255\)/ ],
      "a missing email" => [ { email: nil }, ActiveRecord::NotNullViolation, /email/ ],
      "a blank email" => [ { email: "" }, ActiveRecord::CheckViolation, /readers_email_shape/ ],
      "an email without an at sign" => [ { email: "not-an-email" }, ActiveRecord::CheckViolation, /readers_email_shape/ ],
      "an email with two at signs" => [ { email: "ada@@example.com" }, ActiveRecord::CheckViolation, /readers_email_shape/ ],
      "an email without a local part" => [ { email: "@example.com" }, ActiveRecord::CheckViolation, /readers_email_shape/ ],
      "an email without a domain" => [ { email: "ada@" }, ActiveRecord::CheckViolation, /readers_email_shape/ ],
      "whitespace in an email" => [ { email: "ada lovelace@example.com" }, ActiveRecord::CheckViolation, /readers_email_shape/ ],
      "control characters in an email" => [ { email: "ada\u0007@example.com" }, ActiveRecord::CheckViolation, /readers_email_shape/ ],
      "an email longer than 254 characters" => [ { email: "#{'a' * 243}@example.com" }, ActiveRecord::ValueTooLong, /character varying\(254\)/ ]
    }.each do |violation, (attributes, error, message)|
      it "rejects #{violation}" do
        expect { described_class.insert!(row.merge(attributes)) }.to raise_error(error, message)
      end
    end

    it "keeps a reader who has borrowed a book" do
      reader = create(:borrowing).reader

      expect { reader.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  it "is addressed by its card number" do
    expect(build(:reader, card_number: "100042").to_param).to eq("100042")
  end
end
