require "rails_helper"

RSpec.describe "HTTP protocol" do
  describe "media types" do
    it "always answers JSON, whatever the client accepts" do
      get "/api/v1/books", headers: { "Accept" => "application/xml" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
    end

    it "answers 415 for bodies that are not JSON" do
      post "/api/v1/books", params: "serial_number=000001&title=Dune&author=Herbert", headers: { "Content-Type" => "application/x-www-form-urlencoded" }

      expect(response).to be_problem(:unsupported_media_type, detail: "Request bodies must be application/json")
      expect(Book.count).to eq(0)
    end

    it "answers 400 for a form body that cannot even be decoded" do
      post "/api/v1/books", params: "title=%ff", headers: { "Content-Type" => "application/x-www-form-urlencoded" }

      expect(response).to be_problem(:bad_request)
    end

    it "answers 400 for a Content-Type or Accept header that is not a media type" do
      [ { "Content-Type" => "foo" }, { "Accept" => "foo" } ].each do |headers|
        get "/api/v1/books", headers: headers

        expect(response).to be_problem(:bad_request), headers.inspect
      end
    end

    it "answers 400 for a body that is not valid UTF-8, in a key or a value" do
      [ "{\"\xFF\":\"x\"}", "{\"title\":\"\xFF\"}" ].each do |body|
        post "/api/v1/books", params: body, headers: { "Content-Type" => "application/json" }

        expect(response).to be_problem(:bad_request, detail: "Request body must be valid UTF-8")
      end
    end

    it "answers 400 for bodies that are not valid JSON" do
      [ '{"title":', "#{'[' * 200}#{']' * 200}" ].each do |body|
        post "/api/v1/books", params: body, headers: { "Content-Type" => "application/json" }

        expect(response).to be_problem(:bad_request)
      end
    end
  end

  describe "request ids" do
    it "puts an X-Request-Id on every response, errors included, so a report can be matched to the logs" do
      [ "/api/v1/books", "/api/v1/books/999999", "/nope" ].each do |path|
        get path

        expect(response.headers["X-Request-Id"]).to match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/), path
      end
    end
  end

  describe "routing" do
    it "answers 405 with the allowed methods when the path exists but the method does not" do
      {
        -> { patch "/api/v1/books/000001" } => "GET, HEAD, DELETE",
        -> { delete "/api/v1/books" } => "GET, HEAD, POST",
        -> { get "/api/v1/books/000001/borrowings" } => "POST"
      }.each do |send_request, allowed|
        send_request.call

        expect(response).to be_problem(:method_not_allowed, detail: "#{request.method} is not allowed on #{request.path}")
        expect(response.headers["Allow"]).to eq(allowed)
      end
    end

    it "answers 404 in the problem format for unknown paths and blank identifiers" do
      get "/nope"
      expect(response).to be_problem(:not_found, detail: "No route matches GET /nope")

      get "/api/v1/books/%20"
      expect(response).to be_problem(:not_found, detail: "Book not found")
    end

    it "does not route format suffixes, so writes never run with a non-JSON format" do
      post "/api/v1/books.xml", params: { serial_number: "000001", title: "Dune", author: "Frank Herbert" }, as: :json

      expect(response).to be_problem(:not_found)
      expect(Book.count).to eq(0)
    end

    it "redirects the root to the documentation" do
      get "/"

      expect(response).to redirect_to("/docs")
      expect(response).to have_http_status(:found)
    end

    it "serves the documentation, the problem types and the OpenAPI document" do
      [ "/docs", "/problems", "/openapi/v1.yaml" ].each do |path|
        get path

        expect(response).to have_http_status(:ok), path
      end
    end
  end

  describe "hostile input" do
    it "rejects NUL bytes in the path, the query, the body, keys and arrays" do
      [
        -> { get "/api/v1/books/00000%00" },
        -> { get "/api/v1/books", params: { after: "\0" } },
        -> { get "/api/v1/books?x%00y=1" },
        -> { post "/api/v1/books", params: { serial_number: "000001", title: "a\0b", author: "A" }, as: :json },
        -> { post "/api/v1/books", params: { "extra\0key" => "v" }, as: :json },
        -> { post "/api/v1/books", params: { tags: [ "a\0" ] }, as: :json }
      ].each do |send_request|
        send_request.call

        expect(response).to be_problem(:bad_request, detail: "Parameters must not contain NUL bytes")
      end
    end

    it "answers 400 in the problem format for malformed percent-encoding" do
      [ "/api/v1/books/%FF", "/api/v1/books?after=%ff", "/api/v1/books?after=%", "/health?x=%ff" ].each do |path|
        get path

        expect(response).to be_problem(:bad_request)
      end
    end

    it "answers a host that is not allowed with a 403 problem document" do
      status, headers, body = Rails.application.config.host_authorization.fetch(:response_app).call(Rack::MockRequest.env_for("/"))

      expect([ status, headers["content-type"], JSON.parse(body.join) ]).to eq([
        403, "application/problem+json",
        { "type" => "about:blank", "title" => "Forbidden", "status" => 403, "detail" => "Host not allowed" }
      ])
    end

    it "keeps the health check outside host authorization" do
      exclude = Rails.application.config.host_authorization.fetch(:exclude)

      expect(exclude.call(ActionDispatch::Request.new(Rack::MockRequest.env_for("/health")))).to be(true)
      expect(exclude.call(ActionDispatch::Request.new(Rack::MockRequest.env_for("/api/v1/books")))).to be(false)
    end
  end

  describe "failures" do
    around do |example|
      env_config = Rails.application.env_config
      original = env_config["action_dispatch.show_exceptions"]
      env_config["action_dispatch.show_exceptions"] = :all
      example.run
    ensure
      env_config["action_dispatch.show_exceptions"] = original
    end

    it "answers 503 with Retry-After while the database is unavailable, slow or deadlocked" do
      allow(Rails.logger).to receive(:error)

      {
        "The database is unavailable; retry shortly" => ProblemDetails::DATABASE_DOWN,
        "The database is busy; retry shortly" => ProblemDetails::DATABASE_BUSY
      }.each do |detail, database_errors|
        database_errors.each do |database_error|
          allow(ActiveRecord::Base.connection).to receive(:select_all).and_raise(database_error, "database error")

          get "/api/v1/books"

          expect(response).to be_problem(:service_unavailable, detail:)
          expect(response.headers["Retry-After"]).to eq("5")
        end
      end
    end

    it "answers 500 in the problem format without leaking internals" do
      allow(Catalog::BooksQuery).to receive(:call).and_raise(RuntimeError, "secret internals")

      get "/api/v1/books"

      expect(response).to be_problem(:internal_server_error)
      expect(json).to include(title: "Internal Server Error")
      expect(response.body).not_to include("secret internals")
    end
  end
end
