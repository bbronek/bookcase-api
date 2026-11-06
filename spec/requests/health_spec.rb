require "swagger_helper"

RSpec.describe "Health" do
  before do
    travel_to Time.zone.parse("2026-11-04 10:00")
    allow(Rails.configuration.x).to receive(:booted_at).and_return(123.4.seconds.ago)
  end

  path "/health/live" do
    get "Liveness" do
      tags "Health"
      operationId "getLiveness"
      description "200 while the process can serve requests. Checks no dependencies."
      produces "application/json"

      response "200", "Alive" do
        schema OpenAPISchemas.ref(:Liveness)

        run_test! do
          expect(json).to eq(status: "ok")
          expect(response.headers["Cache-Control"]).to eq("no-store")
        end
      end
    end
  end

  path "/health/ready" do
    get "Readiness" do
      tags "Health"
      operationId "getReadiness"
      description "200 when every dependency answers, 503 otherwise."
      produces "application/json"

      response "200", "Ready" do
        schema OpenAPISchemas.ref(:Readiness)

        run_test! { expect(json).to eq(status: "ok", uptime: 123.4, checks: { database: "ok" }) }
      end

      response "503", "A dependency is down" do
        schema OpenAPISchemas.ref(:Readiness)
        header "Retry-After", schema: { type: :string }, description: "Seconds to wait before probing again."

        before do
          allow(ActiveRecord::Base).to receive(:with_connection).and_raise(ActiveRecord::ConnectionNotEstablished, "connection refused")
          allow(Rails.logger).to receive(:error)
        end

        run_test! do
          expect(json).to eq(status: "unavailable", uptime: 123.4, checks: { database: "error" })
          expect(response.headers["Retry-After"]).to eq("5")
          expect(Rails.logger).to have_received(:error).with("Readiness check failed: database: ActiveRecord::ConnectionNotEstablished: connection refused")
        end
      end
    end
  end

  it "keeps the liveness probe up while the database is down" do
    allow(ActiveRecord::Base).to receive(:with_connection).and_raise(ActiveRecord::ConnectionNotEstablished)

    get "/health/live"

    expect(response).to have_http_status(:ok)
  end
end
