# Bookcase API

A Rails API for library staff to manage physical books, register readers, and track borrowing history. Books are borrowed for 30 days, with email reminders three days before the due date and on the day itself.

Ruby 4.0.9 · Rails 8.1 · PostgreSQL 18 · Solid Queue

## Run it

From the repository root, with Docker and Docker Compose v2 installed:

```sh
docker compose up
```

Open [localhost:3000](http://localhost:3000) for the interactive API reference. No local Ruby, database, SMTP account or environment file is needed. Compose starts PostgreSQL, prepares and seeds the database, then starts Rails and the job worker. If the ports are occupied:

```sh
PORT=3001 DB_PUBLISHED_PORT=5434 docker compose up
```

First boot seeds five books (`000001`–`000005`) and three readers (`100001`–`100003`). The first two books demonstrate reminders, the third has history, and the last two are available. Seed dates are relative to first boot.

`docker compose down` preserves data. `docker compose down -v` permanently removes this stack's database and saved emails. Rebuild after code changes with `docker compose up --build`.

### Try a borrowing

With fresh demo data, `curl` and `jq`: add, borrow, return, inspect history, then withdraw.

```sh
api=http://localhost:3000/api/v1
curl -fsS -X POST "$api/books" -H 'Content-Type: application/json' \
  -d '{"serial_number":"000006","title":"Hyperion","author":"Dan Simmons"}'

borrowing_id=$(curl -fsS -X POST "$api/books/000006/borrowings" \
  -H 'Content-Type: application/json' -d '{"card_number":"100003"}' | jq -er .id)

curl -fsS -X POST "$api/borrowings/$borrowing_id/return"
curl -fsS "$api/books/000006" | jq
curl -fsS -X DELETE "$api/books/000006"
```

Expect `201`, `201`, `200`, `200`, then `204`. The serial number cannot be reused after withdrawal.

### See the emails

Development emails go to a shared volume, not real addresses. Trigger reminders without waiting:

```sh
docker compose exec web bin/rails runner 'ScheduleDueRemindersJob.perform_later'
# After the worker processes the jobs:
docker compose exec web sh -c 'cat tmp/mails/*'
```

A fresh database produces two reminders. [Mailer previews](http://localhost:3000/rails/mailers) show HTML and text templates without jobs.

## API and documentation

Paths below start with `/api/v1`. Serial and card numbers are six-digit strings, preserving leading zeros.

| Method | Path | Purpose |
|---|---|---|
| GET | `/books` | List books with availability and current borrowing |
| POST | `/books` | Add a physical copy |
| GET | `/books/{serial_number}` | Read a book and its full borrowing history |
| DELETE | `/books/{serial_number}` | Withdraw an available book |
| POST | `/books/{serial_number}/borrowings` | Borrow for a registered reader |
| GET | `/borrowings/{id}` | Read one borrowing |
| POST | `/borrowings/{id}/return` | Return that borrowing |
| GET, POST | `/readers` | List or register readers |
| GET | `/readers/{card_number}` | Read a reader |

Filter books by `status=available`, `borrowed` or `withdrawn`; withdrawn books are excluded by default. Lists accept `limit` (default 50, maximum 100) and `after`; the `Link` header points to the next page.

Creates include a `Location` header. Duplicate identifiers or an unavailable book return `409`. Repeated returns and withdrawals are safe. Invalid attributes return `422`; malformed requests return `400`. Application errors share the `application/problem+json` format. `/health/live` checks the process; `/health/ready` also checks PostgreSQL.

[Scalar at `/docs`](http://localhost:3000/docs) provides examples and interactive calls. `script/docs` generates the [OpenAPI contract](public/openapi/v1.yaml) from request specs; tests check route coverage and examples. Scalar needs internet access; the YAML is local at `/openapi/v1.yaml`.

## Architecture and decisions

One Rails application and one PostgreSQL database, shared by application data and Solid Queue. No Redis, separate read store or service framework.

| Layer | Responsibility |
|---|---|
| `app/controllers/api/v1` | Validate request shapes, call a use case, render HTTP |
| `app/domains` | Commands for writes; queries for lists, grouped by catalog, circulation, membership and notifications |
| `app/models` | Associations, normalization, validations and small domain rules |
| `app/serializers/api/v1` | Explicit JSON shapes through Panko |
| `app/jobs`, `app/mailers` | Queue scheduling and email delivery through Action Mailer |

Start with [BorrowBook](app/domains/circulation/borrow_book.rb), the [race tests](spec/integration/concurrency_spec.rb) and [request specs](spec/requests/api/v1/books_spec.rb). [Diagrams](docs/diagrams.md) show the flows.

- **Model the borrowing, not a mutable status flag.** Availability comes from the active borrowing. Returning by borrowing id prevents a repeated old return from closing a newer checkout.
- **Withdraw rather than erase.** History is part of the brief. A withdrawn book remains readable but cannot be lent; its serial number is never reused. Borrowed books must be returned before withdrawal.
- **Validate in Rails; enforce in PostgreSQL.** Models report invalid values and duplicates before saving. Unique indexes, foreign keys, required columns and checks protect stored data even when validations are bypassed. A partial unique index allows one active borrowing per book. Commands preserve `409` conflicts, including concurrent inserts; row locks protect borrow, withdraw and return. Real two-connection tests verify this.
- **Keep HTTP out of workflows.** Commands return records or raise specific errors; one concern maps errors to HTTP responses. Queries preload associations; Panko defines response shapes and encodes them directly to JSON using Oj.
- **Record delivery, not enqueueing.** An hourly 09:00–21:00 Warsaw scheduler queues pending reminders. A unique borrowing/kind pair and queue concurrency control prevent ordinary duplicate deliveries. `sent_at` is written only after delivery succeeds; transient failures retry. Missed three-day reminders can catch up before the due date.

## Checks and local development

With Compose running, execute the suite without installing Ruby locally:

```sh
docker compose exec web sh -c 'bin/rails db:test:prepare && COVERAGE=1 bundle exec rspec'
```

For host development, install the Ruby version in `.ruby-version`, Bundler and Git:

```sh
docker compose up -d db
bin/setup --skip-server
bin/rails server
# In another terminal, for reminder processing:
bin/jobs
```

`bin/rubocop` runs lint; `bin/ci` runs all CI checks. `script/smoke` tests isolated development and production containers and needs Docker, `curl` and `jq`. Tests cover responses, constraints, query counts, races and the reminder lifecycle, with a 100% application line/branch coverage gate. Coverage is not proof of correctness. [AGENTS.md](AGENTS.md) records contribution conventions.

## Scope and limitations

Each serial identifies one copy. Due dates use Europe/Warsaw calendar days; timestamps use UTC. Authentication is omitted as allowed by the brief: do not expose this API publicly without staff access controls. Lost books, renewals, borrowing limits and overdue reminders are out of scope.

Email is not exactly-once: a crash between sending and recording success can duplicate a message; a prolonged outage can miss one. History is unpaginated, and historical interval overlap is not database-enforced.

<details>
<summary>Existing installations and production configuration</summary>

The Compose project and local database names retain `library-api` / `library_api_*` to preserve existing volumes after the Bookcase rename. The simplification migration removes `failed_at` history and retries previously failed reminders within their delivery window; rollback cannot recover those timestamps and requires non-overlapping borrowing history.

The email-shape migration rejects existing malformed addresses rather than rewriting or deleting them. Correct affected records before retrying it. Rails checks full email syntax; SQL checks basic `local@domain` shape and disallows whitespace and control characters.

The Dockerfile also has a `production` target. It requires `SECRET_KEY_BASE`, `DATABASE_URL`, `APP_HOSTS`, `SMTP_ADDRESS` and `MAILER_FROM`; SMTP credentials and port are optional. Run `bin/rails db:prepare`, the web process and `bin/jobs`. TLS must terminate at a trusted proxy. This target is smoke-tested, not a complete deployment setup.

</details>
