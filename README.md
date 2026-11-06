# Bookcase API

A JSON API for library staff: keep a catalog of physical books, register readers, lend and take back books with each book's full borrowing history, and email readers three days before a book is due and on the due date.

Built as a take-home assignment for a Ruby on Rails Developer role.

**Status:** all required features done · 242 specs passing · 100% line and branch coverage · 0 RuboCop offenses

![Ruby 4.0.9](https://img.shields.io/badge/Ruby-4.0.9-CC342D?logo=ruby&logoColor=white)
![Rails 8.1](https://img.shields.io/badge/Rails-8.1_API-D30001?logo=rubyonrails&logoColor=white)
![PostgreSQL 18](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white)
![Solid Queue](https://img.shields.io/badge/jobs-Solid_Queue-555555)
![OpenAPI 3.1](https://img.shields.io/badge/OpenAPI-3.1-6BA539?logo=openapiinitiative&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-compose-2496ED?logo=docker&logoColor=white)

[Quick start](#quick-start) · [API](#api) · [Assumptions](#assumptions) · [Key decisions](#key-decisions--trade-offs) · [Where to look](#where-to-look) · [Testing](#testing-approach) · [Limitations](#known-limitations) · [With more time](#with-more-time) · [Notes](#notes)

---

## Quick start

**Requirements:** Ruby 4.0.9 and PostgreSQL 18, or just Docker with Compose v2.

```bash
# Option A: Docker
docker compose up
# → http://localhost:3000, the interactive API reference

# Option B: local
docker compose up -d db     # PostgreSQL on 127.0.0.1:5433
bin/setup --skip-server     # gems, git hooks, database and seeds
bin/rails server
bin/jobs                    # in a second terminal, for the reminder emails
```

If port 3000 is taken, run `PORT=3001 docker compose up`.

**Run tests**

```bash
bundle exec rspec
bin/rubocop
bin/ci                      # every CI check: lint, security, database, specs and docs
```

Without a local Ruby, the suite runs inside the container: `docker compose exec web sh -c 'bin/rails db:test:prepare && bundle exec rspec'`.

**Try it**

The seeds add five books (`000001` to `000005`) and three readers (`100001` to `100003`). Books `000001` and `000002` are due in three days and today, so the reminders can be tried at once. Book `000003` has a borrowing history. A full borrowing, with `jq` reading the id:

```bash
api=http://localhost:3000/api/v1

curl -X POST "$api/books" -H "Content-Type: application/json" \
  -d '{"serial_number": "000006", "title": "Hyperion", "author": "Dan Simmons"}'

id=$(curl -s -X POST "$api/books/000006/borrowings" -H "Content-Type: application/json" \
  -d '{"card_number": "100003"}' | jq -r .id)

curl -X POST "$api/books/000006/borrowings" -H "Content-Type: application/json" \
  -d '{"card_number": "100001"}'

curl -X POST "$api/borrowings/$id/return"
curl "$api/books/000006"
curl -X DELETE "$api/books/000006"
```

Expect `201`, `201`, `409` because another reader has the book, `200`, `200` with the history, then `204`.

To send the reminders now instead of waiting for the hourly run:

```bash
docker compose exec web bin/rails runner 'ScheduleDueRemindersJob.perform_later'
sleep 5; docker compose exec web sh -c 'cat tmp/mails/*'
```

Development emails are written to files. Templates are previewed at [/rails/mailers](http://localhost:3000/rails/mailers).

---

## API

All paths start with `/api/v1`. Serial and card numbers are six-digit strings, leading zeros included.

| Method | Path | Purpose |
|---|---|---|
| GET | `/books` | List books with availability and current borrowing; `?status=available`, `borrowed` or `withdrawn` |
| POST | `/books` | Add a book |
| GET | `/books/{serial_number}` | A book with its full borrowing history |
| DELETE | `/books/{serial_number}` | Withdraw a book; its history is kept |
| POST | `/books/{serial_number}/borrowings` | Lend the book to a reader for 30 days |
| GET | `/borrowings/{id}` | One borrowing |
| POST | `/borrowings/{id}/return` | Take the book back |
| GET, POST | `/readers` | List or register readers |
| GET | `/readers/{card_number}` | One reader |

Lists take `limit`, 50 by default and at most 100, and `after`; the `Link` header points to the next page. Creates answer `201` with `Location`. Duplicates and unavailable books answer `409`, invalid attributes `422` and malformed requests `400`. Errors use the [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem format, with each type explained at [/problems](http://localhost:3000/problems). `/health/live` and `/health/ready` serve Docker and orchestrators.

The full contract, with examples and live calls, is at [/docs](http://localhost:3000/docs). It is generated from the request specs into [`public/openapi/v1.yaml`](public/openapi/v1.yaml), and CI fails when the committed file is out of date.

---

## Assumptions

- One serial number is one physical copy of a book.
- A reader must be registered before borrowing, and is identified by a card number.
- "Delete a book" means withdraw it: the book leaves the catalog but keeps its history, and its serial number is never reused. A borrowed book must be returned first.
- "Update its status" means borrowing and returning. A book's status is derived from its borrowings, never set directly.
- A borrowing lasts 30 calendar days in the library's time zone, Europe/Warsaw. Reminders go out between 09:00 and 21:00 local time.
- Staff software is the only client, so authentication is left out, as the brief allows.

---

## Key decisions & trade-offs

| Decision | Why | Rejected alternative |
|---|---|---|
| A borrowing is its own resource, returned by its id | The history comes for free, and a repeated old return can never close a newer borrowing | A status column on books, or `POST /books/{serial_number}/return` |
| Withdraw instead of delete | The brief asks for each book's full history, which a delete would erase | Destroying the book, or refusing to delete any book ever lent |
| Rules in Rails validations and in PostgreSQL constraints | Validations give readable `422`s; constraints keep the data valid when validations are bypassed | Validations alone, which concurrent writes and other code can skip |
| Row locks on borrow, withdraw and return | Two staff members acting on one book get one success and one `409` | Checking in Ruby without a lock, which loses a race |
| Command and query objects grouped by area | Each use case reads top to bottom in one file, and controllers stay a few lines long | Fat models mixing several workflows, or full DDD, which four tables do not need |
| One error format, mapped in one place | Clients and docs see a single documented shape | A custom `{error: ...}` body per controller |
| Cursor pagination with a `Link` header | Stable while rows are added, and no count query per page | Page numbers with a total count |
| Reminders as rows, sent by an hourly job | Running again never sends twice, and a missed run catches up | Jobs scheduled at borrow time, lost if one fails |
| Solid Queue on PostgreSQL | Jobs and the schedule live in the database the app already has | Sidekiq, which needs Redis |
| OpenAPI generated from request specs | The docs cannot drift from the behaviour | A hand-written YAML file |

<details>
<summary>Why these gems</summary>

| Gem | Why |
|---|---|
| `rails`, `pg`, `puma`, `bootsnap` | Rails in API mode on PostgreSQL, served by Puma and booted faster by bootsnap |
| `panko_serializer` | Explicit response shapes written straight to JSON through Oj |
| `solid_queue` | Jobs, the hourly schedule and per-reminder concurrency control without Redis |
| `rspec-rails`, `factory_bot_rails`, `shoulda-matchers` | The test stack, with one-line validation and association checks |
| `rswag-specs`, `json_schemer` | OpenAPI generated from request specs, and validated against OpenAPI 3.1 |
| `simplecov` | The 100% line and branch coverage gate |
| `rubocop-rails-omakase` and its plugins | Rails style plus the Performance, RSpec and FactoryBot cops |
| `brakeman`, `bundler-audit` | Static security analysis and known gem vulnerabilities |
| `database_consistency` | Checks that validations, unique indexes and constraints agree |
| `lefthook` | Git hooks for lint, commit messages and the pre-push suite |
| `annotaterb` | Generated schema summaries at the top of each model |

Left out on purpose: Redis-backed queues, pagination and soft-delete gems, result-object libraries and parallel test runners. The app needs none of them at this size, and the suite runs in seconds.

</details>

---

## Where to look

```
app/domains/circulation/borrow_book.rb   ← start here: the lock, the rules and the errors of a borrowing
app/domains/                             ← commands and queries by area: catalog, circulation, membership, notifications
app/controllers/api/v1/                  ← thin JSON controllers
app/models/ and db/migrate/              ← validations, and the constraints that back them
spec/integration/concurrency_spec.rb     ← two staff members racing for one book
spec/requests/api/v1/                    ← request specs that also generate the API docs
```

[docs/diagrams.md](docs/diagrams.md) draws the services, a request's path through the code, the data model, the book states and the reminder pipeline.

---

## Testing approach

- **Model specs:** every validation, and every database constraint proven by writing invalid rows past Rails.
- **Command and query specs:** the business rules, conflicts, idempotent return and withdrawal, and pagination.
- **Request specs:** the success and error responses of each endpoint, with full JSON bodies and query-count checks. They also generate the OpenAPI document.
- **Integration specs:** two real database connections racing for one book, and the reminder lifecycle across several days.
- **Jobs and mailers:** scheduling, retries, both email templates and their previews.
- **Docker smoke test:** `script/smoke` runs `docker compose up` from scratch, exercises the API and the emails, then boots the production image.
- **Not covered:** real SMTP delivery, because the transport is stubbed in tests and development writes files; load and performance testing; and the third-party Scalar page itself.

---

## Known limitations

- **No authentication.** Acceptable for this scope; before exposing the API, it needs staff accounts and access control.
- **Email is at-least-once.** A crash between sending and recording can repeat an email, and an outage lasting a whole day can miss one.
- **A book's history is unpaginated.** Fine for the lifetime of one copy; a very long history would need pagination.
- **Some rules live only in the application.** That a withdrawn book cannot be lent, and that a book is never deleted, are enforced by the commands; SQL would need triggers.
- **Out of scope:** overdue reminders, renewals, borrowing limits and lost books.
- **`/docs` loads Scalar from a CDN**, so the reference page needs internet access; the OpenAPI file is served locally.

---

## With more time

1. **Staff authentication and roles:** required before the API leaves a trusted network.
2. **Titles and copies:** split a title from its physical copies, with authors in their own table, so a library can hold several copies of one book.
3. **Search:** PostgreSQL full-text search over titles and authors.
4. **Overdue reminders, renewals and borrowing limits:** the next rules a real library asks for.
5. **Monitoring:** error tracking, delivery metrics, and failed reminders visible to staff.

---

## Notes

- **Commit history** is kept in small steps on purpose. Read it in order to see how the solution evolved.
- **AI coding agents** follow the instructions in [AGENTS.md](AGENTS.md); [CLAUDE.md](CLAUDE.md) loads them for Claude Code.

<details>
<summary>Production configuration and upgrades</summary>

The Dockerfile has a `production` target. It requires `SECRET_KEY_BASE`, `DATABASE_URL`, `APP_HOSTS`, `SMTP_ADDRESS` and `MAILER_FROM`; SMTP credentials and port are optional. Run `bin/rails db:prepare`, the web process and `bin/jobs`. TLS must end at a trusted proxy. The target is smoke-tested, not a complete deployment setup.

When upgrading an existing database, the email-shape and trimmed-text migrations reject malformed addresses and untrimmed text rather than rewriting them; correct those records before retrying.

</details>
