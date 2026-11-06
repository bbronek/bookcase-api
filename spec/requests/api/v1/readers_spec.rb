require "swagger_helper"

RSpec.describe "API v1 readers" do
  let(:ada_json) { { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" } }

  path "/api/v1/readers" do
    get "List readers" do
      tags "Readers"
      operationId "listReaders"
      description "Readers ordered by card number."
      produces "application/json"
      page_parameters

      response "200", "A page of readers" do
        schema type: :array, items: OpenAPISchemas.ref(:Reader)
        header "Link", schema: { type: :string }, required: false, description: "`<url>; rel=\"next\"` when there is a next page."

        before do
          create(:reader, card_number: "100002", full_name: "Alan Turing", email: "alan@example.com")
          create(:reader, card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com")
        end

        run_test! do
          expect(json).to eq([ ada_json, { card_number: "100002", full_name: "Alan Turing", email: "alan@example.com" } ])
        end
      end
    end

    post "Register a reader" do
      tags "Readers"
      operationId "registerReader"
      description "Registers a reader. Repeating the request with the same attributes answers 200 with the existing reader."
      produces "application/json"
      json_body :Reader

      let(:body) { { card_number: "100001", full_name: "Ada Lovelace", email: " Ada@Example.com " } }

      response "201", "Registered" do
        schema OpenAPISchemas.ref(:Reader)
        header "Location", schema: { type: :string, format: "uri-reference" }, description: "Path of the new reader."

        run_test! do
          expect(json).to eq(ada_json)
          expect(response.headers["Location"]).to eq("/api/v1/readers/100001")
        end
      end

      response "200", "Already registered with the same attributes" do
        schema OpenAPISchemas.ref(:Reader)
        header "Content-Location", schema: { type: :string, format: "uri-reference" }, description: "Path of the existing reader."

        before { create(:reader, **ada_json) }

        run_test! do
          expect(json).to eq(ada_json)
          expect(response.headers["Content-Location"]).to eq("/api/v1/readers/100001")
        end
      end

      problem_response "409", "The card number or email belongs to a different reader",
                       type: "email-taken", detail: "This email belongs to a different reader" do
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

  describe "GET /api/v1/readers" do
    it "pages through readers" do
      create(:reader, card_number: "100001")
      create(:reader, card_number: "100002")

      get "/api/v1/readers", params: { limit: 1 }

      expect(json.pluck(:card_number)).to eq(%w[ 100001 ])
      expect(response.headers["Link"]).to eq('</api/v1/readers?after=100001&limit=1>; rel="next"')
    end
  end

  describe "POST /api/v1/readers" do
    it "refuses a card number that belongs to a different reader" do
      create(:reader, card_number: "100001", full_name: "Someone Else")

      post "/api/v1/readers", params: { card_number: "100001", full_name: "Ada Lovelace", email: "ada@example.com" }, as: :json

      expect(response).to be_problem(:conflict, type: "card-number-taken", detail: "Card number 100001 belongs to a different reader")
    end
  end
end
