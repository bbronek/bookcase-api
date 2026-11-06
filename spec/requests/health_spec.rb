require "swagger_helper"

RSpec.describe "Health" do
  path "/health" do
    get "Health check" do
      tags "Health"
      operationId "getHealth"
      description "200 while the application can reach the database, 503 otherwise."
      produces "application/json"

      response "200", "Healthy" do
        schema OpenAPISchemas.ref(:Health)

        run_test! do
          expect(json).to eq(status: "ok")
          expect(response.headers["Cache-Control"]).to eq("no-store")
        end
      end

      response "503", "The database is unreachable" do
        schema OpenAPISchemas.ref(:Health)
        header "Retry-After", schema: { type: :string }, description: "Seconds to wait before checking again."

        before do
          allow(ActiveRecord::Base).to receive(:with_connection).and_raise(ActiveRecord::ConnectionNotEstablished, "connection refused")
          allow(Rails.logger).to receive(:error)
        end

        run_test! do
          expect(json).to eq(status: "unavailable")
          expect(response.headers["Retry-After"]).to eq("5")
          expect(Rails.logger).to have_received(:error).with("Health check failed: ActiveRecord::ConnectionNotEstablished: connection refused")
        end
      end
    end
  end
end
