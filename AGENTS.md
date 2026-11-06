# AGENTS.md

Working agreement for humans and coding agents. Update this file when a convention changes.

## Scope and structure

Bookcase API: a small library API built with Ruby 4.0.9, Rails 8.1 API mode, PostgreSQL 18, Solid Queue, RSpec, rswag and Panko. Its Rails namespace is `Bookcase`, and its repository folder is `bookcase-api`. Authentication, overdue reminders, extensions, borrowing limits and a frontend are out of scope unless requested.

- `app/controllers/api/v1`: HTTP adapters. Read input through `path_parameter`, `query_parameter` and `body_attributes`; call commands or queries; render serializers.
- `app/domains`: Catalog, Circulation, Membership and Notifications. Plain command/query classes with keyword arguments and `.call`. Commands return records or raise typed domain errors.
- `app/models`: associations, validations, normalization, scopes and small rules. Workflows belong in commands.
- `app/serializers/api/v1`: Panko response shapes. Reuse `ReaderSerializer` for borrowing readers and `BookSummarySerializer` for a borrowing's book. Timestamps use UTC ISO 8601 with three fractional digits. Render records with `serialize_to_json` and collections with `Panko::ArraySerializer`; create serializers per call, not shared instances.
- `app/jobs`: thin wrappers for scheduling and delivery. Mailer templates are in `app/views`; dates and subjects use `config/locales/en.yml`.
- `ProblemDetails` maps application errors to problem JSON. `ErrorsController` answers unmatched routes with 404. `lib/problem.rb` also supports framework exceptions and host authorization.
- `spec/support/openapi`: schemas, a request-spec DSL and recorded examples. Use public rswag configuration, not formatter patches.
- `db/migrate`: forward schema changes. `db/schema.rb` and model schema annotations are generated.

## Commands and completion

```sh
docker compose up -d db
bin/setup --skip-server
bundle exec rspec
COVERAGE=1 bundle exec rspec
bin/rubocop
script/docs
bin/ci
script/smoke
bundle exec annotaterb models
```

Local PostgreSQL defaults to port 5433. Tests always use the test environment; race specs delete test rows.

The Compose project remains explicitly named `library-api`, and local databases remain `library_api_development` and `library_api_test`, to preserve existing volumes and data across the folder rename. New image tags and disposable smoke-test resources use `bookcase-api`.

A change is complete when lint and the full coverage-gated suite pass, affected documentation matches, and generated OpenAPI is current. Run `script/docs` after changing routes, serializers or request specs. Run `bin/ci` before pushing and never skip git hooks. Preserve existing data; do not reset development databases to apply migrations.

## Business and API rules

- Serial numbers and card numbers are unique six-digit strings. Emails are trimmed, lower-cased and unique. Text is trimmed, nonblank, length-limited and rejects control characters, in the model and in PostgreSQL. Use Ruby's built-in email regex.
- Rails validates unique identifiers, one active borrowing per book, one reminder per borrowing/kind, required fields and date ordering. PostgreSQL backs these rules with unique indexes, foreign keys, NOT NULL and CHECK constraints. Each constraint has a spec bypassing validations. Historical interval overlap is not database-enforced.
- Ruby's email regex validates full syntax; PostgreSQL enforces normalized, nonempty `local@domain` shape without whitespace or control characters. Do not duplicate the full email parser in SQL.
- Status is derived from borrowings; never add a status column.
- Books are withdrawn, not destroyed. Catalog queries start from `Book.in_catalog` unless withdrawn books are requested. Withdrawn books remain readable, cannot be lent and retain their serial numbers.
- Borrow and withdraw lock the book before checking state. Return locks the borrowing. Read `Time.current` after acquiring locks. Keep real two-connection race tests.
- Creates return 201 with Location. Duplicate serials, cards and emails return 409 even for identical requests. Borrowing an already borrowed book returns 409 for any reader. Return and withdrawal remain idempotent.
- Duplicate inserts run in a `requires_new` transaction and rescue uniqueness errors outside it, preserving a caller's transaction after a conflict. Commands map uniqueness validation failures to the same 409 conflicts; other invalid attributes remain 422. Keep the database-error path for concurrent inserts that both pass validation.
- Application errors use `application/problem+json`. New conflict types need matching anchors in `public/problems/index.html`. Invalid attributes use `validation-failed` and 422; malformed request shapes or invalid query values use 400. Server-level errors may use the server's format.
- Keep input validation at the boundary: JSON object bodies, string attributes and valid query shapes. Strong parameters select attributes; they do not validate their types.
- Reminders are unique per borrowing and kind, pending until `sent_at` is set after delivery. Skip sent reminders, returned borrowings and expired delivery windows. Keep per-reminder queue concurrency control and bounded transient retries. Other failures surface through the job backend and remain pending.
- Do not promise exactly-once email: a crash between sending and recording success can duplicate delivery. Pending reminders are retried only within their delivery window.
- Do not add application logging of email addresses or SMTP replies. Active Job's failure logs may contain transport replies.
- Time zone changes must update both `config/application.rb` and the borrowing date constraint through a migration.

## Testing and tooling

Use RSpec, FactoryBot and real PostgreSQL. Assert complete success bodies with `eq` and errors with `be_problem`; request specs use `problem_response`. Control time with `travel_to` or `freeze_time`. Use named factory traits. The only sleep in specs is the bounded database lock-wait poll.

Stub edges such as mail transport, outages and unexpected crashes, not business behavior. Preserve the 100% application line and branch coverage gate, but judge tests by the behavior they prove. Delete tests for deliberately removed features.

Keep security checks, database consistency, OpenAPI validation, Docker smoke tests and hooks. The consistency check verifies that unique indexes have matching Rails validators; UUIDv7 supplies time-ordered primary keys. No new dependency when Ruby, Rails or an installed gem already does the job simply.

## Style and changes

Use Omakase layout, double quotes, two-space indentation and `%i[ a b ]`. Endless methods suit single expressions; longer logic uses regular methods. Prefer keyword arguments with shorthand. Use the vocabulary book, reader, borrowing, reminder, withdraw, borrow and return.

No code/configuration comments except generated annotations, shebangs and Docker directives; explain decisions in documentation. Autocorrect only with `bin/rubocop -a --except Layout/LineLength`; wrap long application lines manually. Specs may use longer lines for complete expected bodies, and generated annotation lines may exceed the limit.

Keep changes scoped. Add request specs and regenerate docs for endpoints or response fields. Add database and model specs for stored-data rules. Document required production settings using `ENV.fetch`. Breaking changes after this recruitment submission require a new API version.

Use title-only Conventional Commits: `type(scope): describe the intent`, with an optional scope. Use `feat` for features, `fix` for bug fixes and `!` for breaking changes; a breaking title must describe the contract that changed. Keep implementation, tests and relevant documentation together in one independently testable commit. Separate unrelated behavior, tooling and documentation changes. Do not add AI co-author or generated-by trailers.
