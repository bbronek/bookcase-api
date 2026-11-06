require "rails_helper"

module SharedOpenAPIResponses
  def self.problem(description, headers: {})
    { description:, headers:, content: { Problem::MEDIA_TYPE => { schema: OpenAPISchemas.ref(:Problem) } } }.compact_blank
  end

  def self.ref(name) = { "$ref" => "#/components/responses/#{name}" }

  COMPONENTS = {
    BadRequest: problem("Malformed request, such as invalid JSON or UTF-8, a body that is not a JSON object, or an invalid query value"),
    UnsupportedMediaType: problem("The request body is not `application/json`"),
    ContentTooLarge: {
      description: "The body is over 10 MB; the web server refuses it in plain text before the application runs",
      content: { "text/plain" => { schema: { type: :string } } }
    },
    ServiceUnavailable: problem(
      "The database is down, or a lock wait or statement timed out",
      headers: { "Retry-After" => { schema: { type: :string }, description: "Seconds to wait before retrying." } }
    )
  }.freeze

  ALWAYS = { "503" => ref(:ServiceUnavailable) }.freeze
  MALFORMED = { "400" => ref(:BadRequest) }.freeze
  WITH_BODY = { "413" => ref(:ContentTooLarge), "415" => ref(:UnsupportedMediaType) }.freeze

  OPERATIONS = {
    "/api/v1/books" => { get: ALWAYS, post: MALFORMED.merge(WITH_BODY, ALWAYS) },
    "/api/v1/books/{serial_number}" => { get: MALFORMED.merge(ALWAYS), delete: MALFORMED.merge(ALWAYS) },
    "/api/v1/books/{serial_number}/borrowings" => { post: MALFORMED.merge(WITH_BODY, ALWAYS) },
    "/api/v1/borrowings/{id}" => { get: MALFORMED.merge(ALWAYS) },
    "/api/v1/borrowings/{id}/return" => { post: MALFORMED.merge(ALWAYS) },
    "/api/v1/readers" => { post: MALFORMED.merge(WITH_BODY, ALWAYS) },
    "/api/v1/readers/{card_number}" => { get: MALFORMED.merge(ALWAYS) }
  }.freeze

  def self.paths = OPERATIONS.transform_values { |verbs| verbs.transform_values { |responses| { responses: } } }
end

RSpec.configure do |config|
  config.openapi_root = Rails.public_path.join("openapi").to_s
  config.openapi_format = :yaml
  config.openapi_no_additional_properties = true
  config.openapi_specs = {
    "v1.yaml" => {
      openapi: "3.1.0",
      info: {
        title: "Bookcase API",
        version: "1.0.0",
        description: <<~MARKDOWN
          A JSON API for library staff: the catalog of books, registered readers, lending and returning, and each
          book's borrowing history. Readers are emailed 3 days before a book is due and on the due date.

          ## Typical flow

          1. `POST /api/v1/readers` registers a reader.
          2. `POST /api/v1/books` adds a book.
          3. `POST /api/v1/books/{serial_number}/borrowings` lends it for 30 days and returns the borrowing `id`.
          4. `POST /api/v1/borrowings/{id}/return` takes it back.
          5. `GET /api/v1/books/{serial_number}` shows the book with its full history.

          In development, the seeds provide books `000001` to `000005` and readers `100001` to `100003` to try
          requests with **Test Request**; books `000004` and `000005` are available to lend.

          ## Conventions

          - **Versioning.** Every endpoint lives under `/api/v1`. Additive changes ship in v1; a breaking change
            gets `/api/v2`. Clients must ignore fields they do not know.
          - **Identifiers.** Books are addressed by their six-digit serial number, readers by their six-digit card
            number and borrowings by a UUID.
          - **Requests.** Bodies are JSON objects sent as `application/json` in UTF-8. Another media type answers
            `415` and a malformed body `400`. The web server refuses bodies over 10 MB with a plain-text `413`.
          - **Status codes.** `201` with `Location` for a create, `404` for an unknown resource, `405` with `Allow`
            for an unsupported method, `409` for a conflict, `422` for invalid attributes, and `503` with
            `Retry-After` while the database is down or busy.
          - **Errors** are [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem documents: `type`, `title`,
            `status`, `detail` and, for invalid attributes, `errors` with a JSON pointer per attribute. Each `type`
            is explained at [/problems](/problems).
          - **Conflicts.** A taken serial number, card number or email answers `409`, even for an identical
            request, and so does lending a book that is borrowed or withdrawn.
          - **Safe to repeat.** Returning a returned borrowing answers `200` unchanged, and withdrawing a withdrawn
            book answers `204` again.
          - **Pagination.** The book list is ordered by serial number and paged with a keyset cursor: `limit`
            (1 to 100, default 50) and `after`. The next page is in the `Link: <...>; rel="next"` header.
          - **Time.** Timestamps are UTC, RFC 3339 with milliseconds. Due dates are calendar dates in the library's
            time zone, Europe/Warsaw.
          - **Concurrency.** Writes to one book are serialized by a row lock, so a book has at most one active
            borrowing. A lock wait over 2 s or a statement over 5 s answers `503` with `Retry-After`.
          - **Request ids.** Every response has an `X-Request-Id` header, and production logs are tagged with it.
            Quote it when reporting a problem.
          - **Authentication** is out of scope for this version.
        MARKDOWN
      },
      tags: [
        { name: "Books", description: "The catalog. Withdrawing a book keeps its borrowing history." },
        { name: "Borrowings", description: "Lending a book to a reader and taking it back." },
        { name: "Readers", description: "People with a library card." },
        { name: "Health", description: "The health check, outside the versioned API." }
      ],
      paths: SharedOpenAPIResponses.paths,
      components: { schemas: OpenAPISchemas::ALL, responses: SharedOpenAPIResponses::COMPONENTS }
    }
  }
end
