require "rails_helper"

module SharedOpenAPIResponses
  def self.problem(description, headers: {})
    { description:, headers:, content: { Problem::MEDIA_TYPE => { schema: OpenAPISchemas.ref(:Problem) } } }.compact_blank
  end

  def self.ref(name) = { "$ref" => "#/components/responses/#{name}" }

  COMPONENTS = {
    BadRequest: problem("Malformed request: invalid JSON or UTF-8, a body that is not a JSON object, or invalid query values"),
    UnsupportedMediaType: problem("The request body is not `application/json`"),
    ContentTooLarge: {
      description: "The body is larger than 10 MB, so the web server refuses it before the application, in plain text",
      content: { "text/plain" => { schema: { type: :string } } }
    },
    ServiceUnavailable: problem(
      "The database is down, or a lock wait or statement exceeded its timeout",
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
          A JSON API for library staff: the catalog of books, registered readers, borrowing and returning,
          and each book's borrowing history. Readers are emailed 3 days before a book is due and on the due date.

          ## Conventions

          - **Versioning.** Every endpoint lives under `/api/v1`. Additive changes (new endpoints, new fields) ship in v1;
            a breaking change gets `/api/v2`. Clients must ignore fields they do not know.
          - **Identifiers.** Books are addressed by their six-digit serial number and readers by their six-digit card
            number. Borrowings have a UUIDv7 id.
          - **Media types.** Requests with a body must be `application/json` and valid UTF-8; anything else is
            `415` or `400`. Responses are `application/json`, errors are `application/problem+json`. Only bodies over
            10 MB are refused by the web server itself, with a plain-text `413`.
          - **Errors** follow [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457): `type`, `title`, `status`, `detail`,
            `instance`, the `request_id` (also in the `X-Request-Id` header) and, for invalid attributes, `errors`
            with a JSON pointer per attribute.
          - **Duplicates.** Creates answer `201` with `Location`. An existing serial number, card number or email,
            or a book already borrowed by any reader, answers `409`, even for identical requests.
            Repeating a return answers `200` unchanged, and repeating a withdrawal answers `204`.
          - **Pagination.** Lists are ordered and paginated with a keyset cursor: `limit` (1 to 100, default 50) and
            `after`. The next page, when there is one, is in the `Link: <...>; rel="next"` header.
          - **Time.** Timestamps are UTC (RFC 3339). Due dates are calendar dates in the library's time zone,
            Europe/Warsaw. A borrowing lasts 30 days.
          - **Concurrency.** Simultaneous requests on the same book are serialized by a row lock or a unique index.
            Only one active borrowing per book is allowed. A request that waits more than
            2 s for a lock, or runs a statement longer than 5 s, answers `503` with `Retry-After`.
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
