# Bookcase API

A JSON API for library staff, built with Rails 8.1 and PostgreSQL 18.

The Rails namespace and image tags use Bookcase. The Compose project and local database names retain `library-api` / `library_api_*` to preserve existing volumes and data.

## Run

```sh
docker compose up
```

Open http://localhost:3000/docs for the generated API reference. Compose prepares five books and three readers, then starts Rails and the background worker. Development emails are saved under `tmp/mails` in the worker; previews are at `/rails/mailers`.

## API

All resource routes now live under `/api/v1`; the earlier unversioned routes are removed.

| Method | Path | Purpose |
|---|---|---|
| GET, POST | `/api/v1/books` | List or add books |
| GET, DELETE | `/api/v1/books/{serial_number}` | Read full history or withdraw |
| POST | `/api/v1/books/{serial_number}/borrowings` | Borrow for a registered reader |
| GET | `/api/v1/borrowings/{id}` | Read a borrowing |
| POST | `/api/v1/borrowings/{id}/return` | Return that borrowing |
| GET, POST | `/api/v1/readers` | List or register readers |
| GET | `/api/v1/readers/{card_number}` | Read a reader |

Book and reader numbers are six-digit strings. Text is trimmed without changing internal whitespace or Unicode; control characters are rejected. Email validation uses Ruby's standard pattern. Lists use `limit` and `after`, with a next-page Link header. Books can be filtered by `status`. Errors use problem JSON; the reference documents response bodies and status codes.

Creates return 201 with Location. Duplicate serial numbers, card numbers and emails return 409, even when the request is identical. Repeated borrowing requests also return 409. Returns and withdrawals remain idempotent. Unknown routes and unsupported methods return 404. Request-size enforcement belongs to Puma; server-level errors may use its own format.

## Decisions

Commands in `app/domains` own writes and transactions; controllers translate HTTP; Alba serializers define response shapes. Queries preload related records. PostgreSQL constraints and row locks protect competing writes.

Availability is derived from the active borrowing. Returns target a borrowing id, so a repeated old return cannot close a newer borrowing. Withdrawals keep history and reserve the serial number. History includes the reader's card number, full name and email. UUIDv7 identifies internal records; staff use serial and card numbers.

Borrowings last 30 calendar days in Europe/Warsaw. An hourly daytime scheduler queues reminder deliveries separately, three days before the due date and on the due date. Due-soon reminders can catch up before the due date. Reminders remain pending until sent; temporary failures retry and other failures surface through the job backend. Sending and recording delivery are not atomic, so a crash between them can duplicate an email. Authentication is omitted for this task.

The simplification migration replaces historical overlap exclusion with one-active-borrowing uniqueness and removes reminder failure timestamps. It preserves borrowings and reminders, but cannot restore the old failure timestamps on rollback. Previously failed reminders may retry within their delivery window; rollback requires non-overlapping borrowing history.

## Checks

With Ruby installed, start PostgreSQL with `docker compose up -d db`, then run `DB_PORT=5433 RAILS_ENV=test bin/rails db:test:prepare` and `DB_PORT=5433 bundle exec rspec`. `script/docs` regenerates OpenAPI from the request specs. The suite includes constraint checks and two-connection borrowing, return and withdrawal races.
