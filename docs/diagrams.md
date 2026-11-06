# Diagrams

How the Bookcase API fits together. The [README](../README.md) explains the decisions; the interactive API reference is served at <http://localhost:3000/docs>.

- [Services](#services)
- [A request through the code](#a-request-through-the-code)
- [Data model](#data-model)
- [Book states](#book-states)
- [Two staff members borrow the same book](#two-staff-members-borrow-the-same-book)
- [Reminder emails](#reminder-emails)

## Services

What `docker compose up` starts. `web` and `worker` wait for `migrate`, which waits for a healthy database. Only `127.0.0.1` can reach the published ports. The `mails` volume is mounted in every app container, so `docker compose exec web cat tmp/mails/*` shows what the worker wrote.

```mermaid
flowchart LR
    staff(["Staff client"]) -- "JSON over HTTP :3000" --> web

    subgraph compose["docker compose"]
        direction LR
        migrate["migrate<br/>one-shot db:prepare<br/>schema and seeds"]
        web["web<br/>Puma + Rails API<br/>healthy when /health/ready answers"]
        worker["worker<br/>Solid Queue<br/>scheduler and job workers"]
        db[("db<br/>PostgreSQL 18<br/>domain and queue tables")]
        mails[/"mails volume<br/>delivered emails"/]
    end

    migrate -- "runs first" --> db
    web --> db
    worker -- "polls jobs" --> db
    worker -- "writes emails" --> mails
```

## A request through the code

Controllers only translate HTTP. Commands change state inside a transaction and raise typed domain errors, and one concern turns every error into a problem document.

```mermaid
sequenceDiagram
    autonumber
    participant C as Client
    participant Ctl as API v1 controller
    participant Cmd as Circulation BorrowBook
    participant DB as PostgreSQL
    participant S as Alba serializer
    participant P as ProblemDetails

    C->>Ctl: POST /api/v1/books/000001/borrowings
    Ctl->>Ctl: Content-Type, NUL bytes, string attributes
    Ctl->>Cmd: call(serial_number, card_number)
    Cmd->>DB: BEGIN, SELECT book FOR UPDATE
    Cmd->>DB: reader by card number, active borrowing of this book
    alt no such book
        Cmd-->>P: RecordNotFound
        P-->>C: 404 application/problem+json
    else book withdrawn, or no such reader
        Cmd-->>P: raise BookWithdrawn or UnknownReader
        P-->>C: 409 or 422 application/problem+json
    else no active borrowing
        Cmd->>DB: INSERT borrowing, COMMIT
        Cmd-->>Ctl: new borrowing
        Ctl->>S: serialize
        S-->>Ctl: JSON
        Ctl-->>C: 201 Created, Location /api/v1/borrowings/id
    else book already borrowed, by any reader
        Cmd-->>P: raise BookAlreadyBorrowed
        P-->>C: 409 application/problem+json
    end
```

## Data model

A borrowing links a book to a reader. A book is borrowed while it has a borrowing with no `returned_at`; withdrawn books keep their history. Reminders record which emails went out and remain pending until delivery succeeds.

```mermaid
erDiagram
    BOOKS ||--o{ BORROWINGS : "is lent in"
    READERS ||--o{ BORROWINGS : "borrows"
    BORROWINGS ||--o{ REMINDERS : "is reminded by"

    BOOKS {
        uuid id PK "uuidv7()"
        string serial_number UK "six digits, never reused"
        string title "plain text, at most 255"
        string author "plain text, at most 255"
        timestamptz withdrawn_at "set when withdrawn"
    }
    READERS {
        uuid id PK "uuidv7()"
        string card_number UK "six digits"
        string full_name "plain text, at most 255"
        string email UK "lower-case, at most 254"
    }
    BORROWINGS {
        uuid id PK "uuidv7()"
        uuid book_id FK "one active borrowing per book"
        uuid reader_id FK
        timestamptz borrowed_at
        date due_on "borrow date plus 30 days, Europe/Warsaw, always after the borrow date"
        timestamptz returned_at "null while borrowed, never before borrowed_at"
    }
    REMINDERS {
        uuid id PK "uuidv7()"
        uuid borrowing_id FK "unique with kind"
        reminder_kind kind "enum: due_soon, due_today"
        timestamptz sent_at "set once the email is handed over"
    }
```

## Book states

Each transition is one endpoint. Borrowing an already borrowed book answers 409, including for the same reader. Repeated returns and withdrawals change nothing.

```mermaid
stateDiagram-v2
    [*] --> Available: POST /api/v1/books
    Available --> Borrowed: POST /api/v1/books/{serial_number}/borrowings
    Borrowed --> Available: POST /api/v1/borrowings/{id}/return
    Available --> Withdrawn: DELETE /api/v1/books/{serial_number}
    Borrowed --> Borrowed: any reader borrows, or withdraw, 409
    Withdrawn --> Withdrawn: borrow 409, withdraw again 204

    note right of Withdrawn
        Still readable with its history,
        listed with ?status=withdrawn,
        serial number never reused
    end note
```

## Two staff members borrow the same book

The book row is locked before the check, so the second request waits for the first to commit and then sees the borrowing. A wait longer than the 2 s lock timeout answers `503` with `Retry-After`. A partial unique index independently prevents two active borrowings of the same book; it does not constrain historical intervals.

```mermaid
sequenceDiagram
    participant A as Request A, reader 100001
    participant B as Request B, reader 100002
    participant DB as PostgreSQL

    A->>DB: BEGIN, SELECT book FOR UPDATE
    B->>DB: BEGIN, SELECT book FOR UPDATE, waits up to 2 s
    A->>DB: no active borrowing, INSERT, COMMIT
    DB-->>B: lock granted
    B->>DB: active borrowing by another reader
    B-->>B: ROLLBACK, 409 book already borrowed
```

## Reminder emails

The scheduler runs every hour from 09:00 to 21:00 Europe/Warsaw. Each reminder is a row, unique per borrowing and kind. Every run queues pending reminders still within their delivery window. A reminder marked sent is not queued again. A crash after sending but before recording success can cause a duplicate email; an outage beyond the window can cause a missed email.

```mermaid
sequenceDiagram
    autonumber
    participant Q as Solid Queue scheduler
    participant S as ScheduleDueRemindersJob
    participant DB as PostgreSQL
    participant D as DeliverReminderJob
    participant M as ReminderMailer

    Q->>S: every hour, 09:00 to 21:00 Europe/Warsaw
    S->>DB: active borrowings due today, and due in 1 to 3 days
    S->>DB: INSERT reminders ON CONFLICT DO NOTHING
    S->>DB: SELECT pending reminders for those borrowings
    S->>Q: one DeliverReminderJob per reminder
    Q->>D: perform, one per reminder at a time, duplicates dropped
    alt not pending, the book was returned, or the email is no longer timely
        D-->>Q: nothing to do
    else
        D->>M: due_soon or due_today, text and HTML
        alt delivered
            D->>DB: UPDATE sent_at
        else timeout or busy server
            D-->>Q: retry with backoff, up to 5 attempts, then the next run
        else any other failure
            D-->>Q: fail loudly, next eligible run tries again
        end
    end
```
