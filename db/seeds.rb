# Idempotent sample data so the API is explorable right after `docker compose up`.
# Includes one borrowing due in 3 days and one due today, so running DueDateRemindersJob sends two emails immediately.

books = [
  [ "000001", "Dune", "Frank Herbert" ],
  [ "000002", "The Left Hand of Darkness", "Ursula K. Le Guin" ],
  [ "000003", "Neuromancer", "William Gibson" ],
  [ "000004", "Solaris", "Stanisław Lem" ],
  [ "000005", "The Dispossessed", "Ursula K. Le Guin" ]
].map { |serial_number, title, author| Book.find_or_create_by!(serial_number:) { |b| b.title, b.author = title, author } }

readers = [
  [ "100001", "Ada Lovelace", "ada@example.com" ],
  [ "100002", "Alan Turing", "alan@example.com" ],
  [ "100003", "Grace Hopper", "grace@example.com" ]
].map { |card_number, full_name, email| Reader.find_or_create_by!(card_number:) { |r| r.full_name, r.email = full_name, email } }

if Borrowing.none?
  dune, left_hand, neuromancer = books
  ada, alan, grace = readers

  dune.borrow!(ada, now: 27.days.ago)                     # due in 3 days  -> "upcoming" reminder today
  left_hand.borrow!(alan, now: 30.days.ago)               # due today      -> "due_today" reminder today
  neuromancer.borrow!(grace, now: 60.days.ago)            # returned: shows up only in the history
  neuromancer.return!(now: 40.days.ago)
  neuromancer.borrow!(ada, now: 2.days.ago)               # borrowed again, due in 28 days
end
