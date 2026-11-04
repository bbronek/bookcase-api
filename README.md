# Library API

[![CI](https://github.com/bbronek/library-api/actions/workflows/ci.yml/badge.svg)](https://github.com/bbronek/library-api/actions/workflows/ci.yml)

A small JSON API for library staff: register books and readers, borrow and return books, see each book's borrowing history, and remind readers by email before a book is due.

Ruby 4.0 · Rails 8.1 (API mode) · PostgreSQL 17 · Solid Queue · RSpec

## Quick start

```sh
docker compose up
```

That builds the image, starts PostgreSQL, creates and seeds the database, then starts the API on <http://localhost:3000> and a job worker. No other steps.

| Service   | What it does                                                                                   |
|-----------|------------------------------------------------------------------------------------------------|
| `db`      | PostgreSQL 17 (also published on `127.0.0.1:5433` for `psql`; override with `DB_PUBLISHED_PORT`) |
| `migrate` | One-shot `rails db:prepare`: schema, migrations and seeds. The other two services wait for it. |
| `web`     | Puma on port 3000 (override with `PORT=3001 docker compose up`)                                |
| `worker`  | Solid Queue: runs the daily reminder job                                                       |

Seed data: five books, three readers, one book due in 3 days, one due today and one with a past borrowing in its history. See `db/seeds.rb`.

## API

All responses are JSON. Request bodies are JSON (`Content-Type: application/json`). Books are addressed by serial number and readers by library card number, because those are the identifiers staff have in hand.

| Method | Path                               | Purpose                                          | Success | Errors             |
|--------|------------------------------------|--------------------------------------------------|---------|--------------------|
| GET    | `/books`                           | All books with availability and current borrower | 200     |                    |
| GET    | `/books/:serial_number`            | One book with its full borrowing history         | 200     | 404                |
| POST   | `/books`                           | Add a book                                       | 201     | 400, 422           |
| DELETE | `/books/:serial_number`            | Delete a book (and its history)                  | 204     | 404, 409           |
| POST   | `/books/:serial_number/borrowings` | Borrow the book for a reader (30 days)           | 201     | 400, 404, 409, 422 |
| POST   | `/books/:serial_number/return`     | Return the book                                  | 200     | 404, 409           |
| GET    | `/readers`                         | All readers                                      | 200     |                    |
| POST   | `/readers`                         | Register a reader                                | 201     | 400, 422           |

### Examples

```sh
# Add a book
curl -s -X POST localhost:3000/books -H 'Content-Type: application/json' \
  -d '{"serial_number":"123456","title":"Hyperion","author":"Dan Simmons"}'

# Register a reader
curl -s -X POST localhost:3000/readers -H 'Content-Type: application/json' \
  -d '{"card_number":"100009","full_name":"Linus Torvalds","email":"linus@example.com"}'

# Borrow it (due 30 days from now)
curl -s -X POST localhost:3000/books/123456/borrowings -H 'Content-Type: application/json' \
  -d '{"card_number":"100009"}'

# List all books with status
curl -s localhost:3000/books

# One book with its history
curl -s localhost:3000/books/123456

# Return it
curl -s -X POST localhost:3000/books/123456/return

# Delete it
curl -s -i -X DELETE localhost:3000/books/123456
```

A book in the list:

```json
{
  "serial_number": "000001",
  "title": "Dune",
  "author": "Frank Herbert",
  "status": "borrowed",
  "current_borrowing": {
    "id": 1,
    "borrowed_at": "2026-10-08T12:01:58.159Z",
    "due_on": "2026-11-07",
    "reader": { "card_number": "100001", "full_name": "Ada Lovelace", "email": "ada@example.com" }
  }
}
```

`GET /books/:serial_number` adds `"borrowings": [...]`, newest first, each with `borrowed_at`, `due_on`, `returned_at` and the reader.

### Errors

One shape everywhere:

```json
{ "error": "Validation failed", "details": { "serial_number": ["must be exactly six digits"] } }
{ "error": "Book 000001 is already borrowed" }
```

| Status | When                                                                                           |
|--------|------------------------------------------------------------------------------------------------|
| 400    | Required parameter missing                                                                     |
| 404    | Unknown book or reader in the URL                                                              |
| 409    | State conflict: borrowing a borrowed book, returning an available one, deleting a borrowed one |
| 422    | Validation failed, including an unknown `card_number` in the borrow body                       |

## Reminder emails

Every borrowing lasts 30 days. Readers get an email 3 days before the due date and on the due date.

`DueDateRemindersJob` runs every day at 09:00 (`config/recurring.yml`, executed by the Solid Queue scheduler in the `worker` service). It selects active borrowings due in 3 days and due today, and sends one `ReminderMailer` email per match. Each sent email is recorded in the `reminders` table, one row per `(borrowing, kind)`, so running the job twice on the same day never sends twice.

No real emails are sent. The full payload is written to the log. To see it right away instead of waiting for 09:00:

```sh
docker compose exec web bin/rails runner 'DueDateRemindersJob.perform_now'
```

The seed data contains one borrowing due in 3 days and one due today, so this prints two emails. Run it again and nothing is sent. A missed day can be replayed with `DueDateRemindersJob.perform_now(Date.yesterday)`.

Mailer previews: <http://localhost:3000/rails/mailers/reminder_mailer>.

## Design decisions

**Availability is derived, not stored.** There is no `status` column. A book is borrowed when it has a borrowing with `returned_at IS NULL`. One fact, one place, nothing to keep in sync.

**The database enforces the invariants.** A partial unique index on `borrowings (book_id) WHERE returned_at IS NULL` guarantees at most one active borrowing per book. Two staff members borrowing the same book at the same instant cannot both succeed: the second insert fails and the API answers 409. The six-digit formats and `returned_at >= borrowed_at` are check constraints as well, so no code path, including console and bulk imports, can store an invalid row. Model validations exist on top for friendly error messages.

**Borrow and return are actions, not a status field.** The task describes "update the book status: borrowed / available". Borrowing needs a reader and creates history; returning does not and closes it. They have different preconditions and different side effects, so they are two endpoints (`POST .../borrowings`, `POST .../return`) rather than a `PATCH` with a `status` value. Invalid transitions cannot be expressed.

**Natural keys in URLs.** Serial numbers and card numbers are what the staff type in. Database ids are not exposed for books and readers.

**Serial and card numbers are strings.** `000042` is a valid six-digit number; an integer column would lose the leading zeros.

**Due date is a date.** The loan is 30 days and the reminders are "3 days before the due date" and "on the due date", which are calendar rules. `borrowed_at` is a timestamp for the history; `due_on` is a date. Reminders go out at a fixed hour from a daily job instead of being scheduled per borrowing at borrow time. That keeps the rule in one query, works even if a due date is ever changed, and does not depend on jobs scheduled a month ahead surviving deploys and queue maintenance.

**Reminders are idempotent and auditable.** The `reminders` table with its unique `(borrowing_id, kind)` index is what makes retries safe. Delivery is at-least-once: if the process died between sending and recording `sent_at`, the next run would resend that one email. For a library reminder, a rare duplicate beats a silent miss.

**Solid Queue, one database, no Redis.** Rails 8's default job backend, running against the application database (the Solid Queue tables are a normal migration). One fewer service for the reviewer and for production. Sidekiq would be the swap if throughput ever demanded it.

**Delete is a hard delete.** Deleting a book removes its borrowing history, as the task asks for deletion. A borrowed book cannot be deleted (409). For a real library I would archive instead of delete, see below.

**The Docker image runs the `development` environment.** On purpose: requests and email payloads go to stdout, mailer previews are available, and there are no secrets to manage. A production image would be multi-stage, run `RAILS_ENV=production` with `SECRET_KEY_BASE` from the environment and a separate queue database.

**Reader endpoints are minimal.** The task does not ask for reader management, but borrowing needs readers to exist, so `POST /readers` and `GET /readers` are included. No update or delete.

## Limitations and next steps

- **Authentication and authorization** are omitted as allowed by the task. JWT for staff clients or Devise sessions for a staff UI would go in `ApplicationController`.
- **Pagination** is absent; `GET /books` returns everything. Cursor pagination on `serial_number` is the obvious addition.
- **Soft delete / archiving** of books so history survives deletion.
- **Reader lifecycle**: updating details, deactivating a card, and emailing a reader when their card changes.
- **Per-email jobs**: today the daily job sends emails in a loop. Fanning out one job per reminder would isolate a single failing delivery and parallelise sending at scale.
- **Time zone**: the app runs in UTC; "due today" means the UTC date. A library would set `config.time_zone` to its local zone.
- **PII in logs**: email payloads are logged in full, which is right for this demo and wrong for production. Parameter filtering and a real delivery method would replace it.
- **API documentation**: an OpenAPI document (for example via `rswag`) generated from the request specs.
- **Observability**: request ids are present; structured logging and error tracking are not.

## Development

Requirements: Ruby 4.0 (`.ruby-version`) and a PostgreSQL to point at. The compose `db` service works: it is published on port 5433.

```sh
docker compose up -d db
export DB_PORT=5433            # database.yml reads DB_HOST, DB_PORT, DB_USER, DB_PASSWORD
bin/setup --skip-server        # bundle, db:prepare
bundle exec rspec              # 64 examples
bin/ci                         # rubocop, bundler-audit, brakeman, rspec
bin/rails server
```

The GitHub Actions workflow runs the same four checks on every push.

## Process

Built with AI assistance (Claude Code) and reviewed line by line: every design decision above, every test and the data model are mine, and nothing was merged that I could not defend in a code review.
