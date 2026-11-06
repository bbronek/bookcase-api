require "swagger_helper"

RSpec.describe "API v1 readers" do
  let(:ada_json) { { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" } }

  path "/api/v1/readers" do
    post "Register a reader" do
      tags "Readers"
      operationId "registerReader"
      description "Registers a reader. The email is stored trimmed and lower-cased. A card number or email already registered answers 409."
      produces "application/json"
      json_body :Reader

      let(:body) { { card_number: "100001", full_name: "Ada Lovelace", email: " Ada@Example.com " } }

      response "201", "Reader registered" do
        schema OpenAPISchemas.ref(:Reader)
        header "Location", schema: { type: :string, format: "uri-reference" }, description: "Path of the new reader."

        run_test! do
          expect(json).to eq(ada_json)
          expect(response.headers["Location"]).to eq("/api/v1/readers/100001")
        end
      end

      problem_response "409", "The card number or email is already registered",
                       type: "email-taken", detail: "This email is already registered" do
        before { create(:reader, card_number: "100002", email: "ada@example.com") }
      end

      problem_response "422", "Invalid attributes",
                       type: "validation-failed", detail: "The request has invalid attributes",
                       errors: [
                         { pointer: "#/card_number", detail: "must be exactly six digits" },
                         { pointer: "#/full_name", detail: "can't be blank" },
                         { pointer: "#/email", detail: "is invalid" }
                       ] do
        let(:body) { { card_number: "1", full_name: "", email: "nope" } }
      end
    end
  end

  path "/api/v1/readers/{card_number}" do
    parameter name: :card_number, in: :path, required: true, schema: OpenAPISchemas::CARD_NUMBER

    get "Get a reader" do
      tags "Readers"
      operationId "getReader"
      description "A registered reader, by card number."
      produces "application/json"

      let(:card_number) { "100001" }

      response "200", "The reader" do
        schema OpenAPISchemas.ref(:Reader)

        before { create(:reader, **ada_json) }

        run_test! { expect(json).to eq(ada_json) }
      end

      problem_response "404", "No reader with this card number", detail: "Reader not found"
    end
  end

  describe "POST /api/v1/readers" do
    it "refuses an identical registration" do
      create(:reader, **ada_json)

      post "/api/v1/readers", params: ada_json, as: :json

      expect(response).to be_problem(:conflict, type: "card-number-taken")
      expect(Reader.count).to eq(1)
    end
  end
end
