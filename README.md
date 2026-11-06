# Bookcase API

A JSON API for library staff: keep a catalog of physical books, register readers, lend and take back books with each book's full borrowing history, and email readers three days before a book is due and on the due date.

**Status:** feature-complete · 206 specs · `bin/ci` runs lint, security scans, database checks and the specs · `script/smoke` runs everything in Docker

![Ruby 4.0.9](https://img.shields.io/badge/Ruby-4.0.9-CC342D?logo=ruby&logoColor=white)
![Rails 8.1](https://img.shields.io/badge/Rails-8.1_API-D30001?logo=rubyonrails&logoColor=white)
![PostgreSQL 18](https://img.shields.io/badge/PostgreSQL-18-4169E1?logo=postgresql&logoColor=white)
![Solid Queue](https://img.shields.io/badge/jobs-Solid_Queue-555555)
![OpenAPI 3.1](https://img.shields.io/badge/OpenAPI-3.1-6BA539?logo=openapiinitiative&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-compose-2496ED?logo=docker&logoColor=white)

[Quick start](#quick-start) · [API](#api) · [Architecture](#architecture) · [Assumptions](#assumptions) · [Key decisions](#key-decisions--trade-offs) · [Testing](#testing-approach) · [Limitations](#known-limitations) · [Improvements](#ideas-for-improvements) · [Notes](#notes)

---

## Quick start

**You need** Git and Docker with Compose v2. Ruby 4.0.9 is optional, for running the app and the tests outside Docker. The try-it commands use `curl` and `jq`.

**Get the code**

```bash
git clone https://github.com/bbronek/bookcase-api.git
cd bookcase-api
```

**Run with Docker**

```bash
docker compose up
```

Open [localhost:3000](http://localhost:3000): it redirects to the interactive API docs. Compose starts PostgreSQL, migrates and seeds the database, and runs the web server and the job worker. Every `docker compose up` rebuilds the image from the current code, so changes and `git pull` need no extra flags. If port 3000 is taken, pick another one: `PORT=3001 docker compose up`. `docker compose down -v` starts over with a fresh database.

**Run locally**

```bash
docker compose up -d db      # PostgreSQL 18 on 127.0.0.1:5433
bin/setup --skip-server      # gems, git hooks, database and seeds
bin/rails server             # http://localhost:3000
bin/jobs                     # in a second terminal, for the reminder emails
```

**Run the tests**

```bash
bundle exec rspec            # needs the database from "Run locally"
bin/rubocop
bin/ci                       # every CI check: lint, security, database, specs and docs
```

Without a local Ruby, the suite runs inside the container: `docker compose exec web sh -c 'bin/rails db:test:prepare && bundle exec rspec'`.

**Try it**

The seeds add five books (`000001` to `000005`) and three readers (`100001` to `100003`). Books `000001` and `000002` are due in three days and today, so the reminders can be tried at once. Book `000003` has a borrowing history. A full borrowing:

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

---

## API

All paths start with `/api/v1`. Serial and card numbers are six-digit strings, leading zeros included.

| Method | Path | Purpose |
|---|---|---|
| GET | `/books` | List books with availability and current borrowing |
| POST | `/books` | Add a book |
| GET | `/books/{serial_number}` | A book with its full borrowing history |
| DELETE | `/books/{serial_number}` | Withdraw a book; its history is kept |
| POST | `/books/{serial_number}/borrowings` | Lend the book to a reader for 30 days |
| GET | `/borrowings/{id}` | One borrowing |
| POST | `/borrowings/{id}/return` | Take the book back |
| POST | `/readers` | Register a reader |
| GET | `/readers/{card_number}` | One reader |

- **Status codes:** creates answer `201` with `Location`. Unknown resources answer `404`, duplicates and unavailable books `409`, invalid attributes `422`, malformed requests `400`, and an unsupported method on an existing path `405` with `Allow`. A database that is down or busy answers `503` with `Retry-After`.
- **Errors:** one [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457) problem format, each type explained at [/problems](http://localhost:3000/problems). The only exception is a body over 10 MB, which the web server refuses with a plain-text `413` before the application runs. Every response carries an `X-Request-Id` header to quote when reporting a problem.
- **Pagination:** `GET /books` takes `limit`, 50 by default and at most 100, and `after`; the `Link` header points to the next page.
- **Health:** `/health` answers `200` while the database is reachable and `503` otherwise.

**Documentation**

| Where | What |
|---|---|
| [/docs](http://localhost:3000/docs) | Interactive reference with examples; every endpoint can be called from the page |
| [`public/openapi/v1.yaml`](public/openapi/v1.yaml) | The OpenAPI 3.1 contract, generated from the request specs; CI fails when it is out of date |
| [/problems](http://localhost:3000/problems) | Every error type the API returns |
| [/rails/mailers](http://localhost:3000/rails/mailers) | Previews of both reminder emails, in text and HTML |
| [docs/diagrams.md](docs/diagrams.md) | The services, a request through the code, the data model, the book states, two staff members racing for one book and the reminder pipeline |

---

## Architecture

One Rails application in API mode, one PostgreSQL database and one Solid Queue worker, all built from one Docker image. There is no Redis: jobs and their schedule live in PostgreSQL.

```
request → app/controllers/api/v1    check the request shape, call one command or query
        → app/domains                commands change state under row locks; the query pages through the book list
        → app/models + PostgreSQL    validations, and the constraints that back them
        → app/serializers/api/v1     the JSON response

errors → ProblemDetails in controllers, lib/problem.rb before them → one problem+json format

hourly ScheduleDueRemindersJob → one DeliverReminderJob per pending reminder → ReminderMailer
```

The business rules live in four areas under `app/domains`: catalog, circulation, membership and notifications. Start reading here:

```
app/domains/circulation/borrow_book.rb   the lock, the rules and the errors of a borrowing
spec/integration/concurrency_spec.rb     two staff members racing for one book
spec/requests/api/v1/                    request specs that also generate the API docs
```

---

## Assumptions

- One serial number is one physical copy of a book.
- A reader must be registered before borrowing, and is identified by a card number.
- "Delete a book" means withdraw it: the book leaves the catalog but keeps its history, and its serial number is never reused. A borrowed book must be returned first.
- "Update its status" means borrowing and returning. A book's status is derived from its borrowings, never set directly.
- A borrowing lasts 30 calendar days in the library's time zone, Europe/Warsaw. Reminders go out at 09:00 local time; hourly runs until 21:00 queue any still pending after a failure or outage.
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
| Everything under `/api/v1` | A breaking change gets `/api/v2` while v1 keeps working | Unversioned routes |

<details>
<summary>Why these gems</summary>

| Gem | Why |
|---|---|
| `rails`, `pg`, `puma`, `bootsnap` | Rails in API mode on PostgreSQL, served by Puma and booted faster by bootsnap |
| `panko_serializer` | Explicit response shapes written straight to JSON through Oj |
| `solid_queue` | Jobs, the hourly schedule and per-reminder concurrency control without Redis |
| `rspec-rails`, `factory_bot_rails`, `shoulda-matchers` | The test stack, with one-line validation and association checks |
| `rswag-specs`, `json_schemer` | OpenAPI generated from request specs, and validated against OpenAPI 3.1 |
| `simplecov` | Line and branch coverage reports, so code no spec exercises shows up in CI |
| `rubocop-rails-omakase` and its plugins | Rails style plus the Performance, RSpec and FactoryBot cops |
| `brakeman`, `bundler-audit` | Static security analysis and known gem vulnerabilities |
| `database_consistency` | Checks that validations, unique indexes and constraints agree |
| `lefthook` | Git hooks for lint, commit messages and the pre-push suite |
| `annotaterb` | Generated schema summaries at the top of each model |

Left out on purpose: Redis-backed queues, pagination and soft-delete gems, result-object libraries and parallel test runners. The app needs none of them at this size, and the suite runs in seconds.

</details>

---

## Testing approach

- **Model specs:** every validation, and every CHECK, unique and length constraint proven by writing invalid rows past Rails. `database_consistency` proves that NOT NULL columns and foreign keys match the validations.
- **Command specs:** the business rules, conflicts, and idempotent return and withdrawal. Each rule is proven once, at the layer that owns it.
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

## Ideas for improvements

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
<summary>Production configuration</summary>

The Dockerfile has a `production` target. It requires `SECRET_KEY_BASE`, `DATABASE_URL`, `APP_HOSTS`, `SMTP_ADDRESS` and `MAILER_FROM`. Optional: `SMTP_PORT`, `SMTP_USERNAME` and `SMTP_PASSWORD`, plus `RAILS_MAX_THREADS`, `JOB_THREADS`, `JOB_CONCURRENCY` and `RAILS_LOG_LEVEL` for tuning. Run `bin/rails db:prepare`, the web process and `bin/jobs`. TLS must end at a trusted proxy. The target is smoke-tested, not a complete deployment setup.

</details>
