# Library API

A JSON API for library staff, built with Rails 8.1 and PostgreSQL 18.

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

## Decisions

Commands in `app/domains` own writes and transactions; controllers translate HTTP; Alba serializers define response shapes. Queries preload related records. PostgreSQL constraints and row locks protect competing writes.

Availability is derived from the active borrowing. Returns target a borrowing id, so a repeated old return cannot close a newer borrowing. Withdrawals keep history and reserve the serial number. History includes the reader's card number, full name and email. UUIDv7 identifies internal records; staff use serial and card numbers.

Borrowings last 30 calendar days in Europe/Warsaw. An hourly daytime scheduler queues reminder deliveries separately, three days before the due date and on the due date. Due-soon reminders can catch up before the due date. Transient failures retry; rejected recipient addresses are recorded as failed. Sending and recording delivery are not atomic, so a crash between them can duplicate an email. Authentication is omitted for this task.

## Checks

With Ruby installed, start PostgreSQL with `docker compose up -d db`, then run `DB_PORT=5433 RAILS_ENV=test bin/rails db:test:prepare` and `DB_PORT=5433 bundle exec rspec`. `script/docs` regenerates OpenAPI from the request specs. The suite includes constraint checks and two-connection borrowing, return and withdrawal races.
