require "rails_helper"

RSpec.describe Membership::RegisterReader do
  def register(card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com")
    described_class.call(card_number:, full_name:, email:)
  end

  it "registers a reader with a normalized email" do
    reader = register(email: " Ada@Example.com ")

    expect(reader).to be_persisted.and(be_previously_new_record)
    expect(reader).to have_attributes(card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com")
  end

  it "rejects invalid attributes" do
    expect { register(card_number: "1", email: "nope") }.to raise_error(ActiveRecord::RecordInvalid) { |error|
      expect(error.record.errors.to_hash).to eq(card_number: [ "must be exactly six digits" ], email: [ "is invalid" ])
    }
  end

  it "refuses a taken card number, even when the attributes are identical" do
    register

    expect { register(email: "ADA@example.com") }
      .to raise_error(Membership::RegisterReader::CardNumberTaken, "Card number 100001 is already registered")
    expect(Reader.count).to eq(1)
  end

  it "keeps invalid attributes as validation errors even when identifiers are taken" do
    register

    expect { register(full_name: "") }.to raise_error(ActiveRecord::RecordInvalid) { |error|
      expect(error.record.errors.of_kind?(:full_name, :blank)).to be(true)
    }
  end

  it "refuses an email that belongs to a different reader" do
    register

    expect { register(card_number: "100002") }.to raise_error(Membership::RegisterReader::EmailTaken, "This email is already registered")
  end
end
