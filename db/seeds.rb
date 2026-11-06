return unless Rails.env.development?

[
  [ "000001", "Dune", "Frank Herbert" ],
  [ "000002", "The Left Hand of Darkness", "Ursula K. Le Guin" ],
  [ "000003", "Neuromancer", "William Gibson" ],
  [ "000004", "Solaris", "Stanisław Lem" ],
  [ "000005", "The Dispossessed", "Ursula K. Le Guin" ]
].each { |serial_number, title, author| Catalog::AddBook.call(serial_number:, title:, author:) }

[
  [ "100001", "Ada Lovelace", "ada@example.com" ],
  [ "100002", "Alan Turing", "alan@example.com" ],
  [ "100003", "Grace Hopper", "grace@example.com" ]
].each { |card_number, full_name, email| Membership::RegisterReader.call(card_number:, full_name:, email:) }

if Borrowing.none?
  borrowed_to_be_due_soon = 3.days.from_now - Borrowing::PERIOD
  borrowed_to_be_due_today = Time.current - Borrowing::PERIOD

  Circulation::BorrowBook.call(serial_number: "000001", card_number: "100001", borrowed_at: borrowed_to_be_due_soon)
  Circulation::BorrowBook.call(serial_number: "000002", card_number: "100002", borrowed_at: borrowed_to_be_due_today)

  previous_borrowing = Circulation::BorrowBook.call(
    serial_number: "000003", card_number: "100003", borrowed_at: 60.days.ago
  )
  Circulation::ReturnBook.call(borrowing_id: previous_borrowing.id, returned_at: 40.days.ago)
  Circulation::BorrowBook.call(serial_number: "000003", card_number: "100001", borrowed_at: 2.days.ago)
end
