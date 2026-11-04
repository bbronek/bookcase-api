require "rails_helper"

RSpec.describe "Readers" do
  describe "GET /readers" do
    it "lists readers" do
      create(:reader, card_number: "100002", full_name: "Alan Turing", email: "alan@example.com")
      create(:reader, card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com")

      get "/readers"

      expect(response).to have_http_status(:ok)
      expect(json).to eq([
        { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" },
        { card_number: "100002", full_name: "Alan Turing", email: "alan@example.com" }
      ])
    end
  end

  describe "POST /readers" do
    it "registers a reader with a normalized email" do
      post "/readers", params: { card_number: "100001", full_name: "Ada Lovelace", email: " Ada@Example.com " }, as: :json

      expect(response).to have_http_status(:created)
      expect(json).to eq(card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com")
    end

    it "rejects duplicate emails regardless of case" do
      create(:reader, email: "ada@example.com")

      post "/readers", params: { card_number: "100001", full_name: "Ada Lovelace", email: "ADA@example.com" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:details]).to eq(email: [ "has already been taken" ])
    end

    it "rejects invalid attributes" do
      post "/readers", params: { card_number: "1", full_name: "", email: "nope" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json[:details]).to eq(card_number: [ "must be exactly six digits" ], full_name: [ "can't be blank" ], email: [ "is invalid" ])
    end
  end
end
