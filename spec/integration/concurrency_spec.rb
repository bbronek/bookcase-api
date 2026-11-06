require "rails_helper"

RSpec.describe "Concurrent requests" do
  self.use_transactional_tests = false

  def delete_all_rows = [ Reminder, Borrowing, Book, Reader ].each(&:delete_all)

  after { delete_all_rows }

  def start_waiting_for_lock
    thread = Thread.new do
      Thread.current.report_on_exception = false
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        Thread.current[:backend_pid] = connection.select_value("SELECT pg_backend_pid()")
        yield
      end
    end
    Timeout.timeout(5) { sleep 0.01 until thread[:backend_pid] && (waiting_on_lock?(thread[:backend_pid]) || !thread.alive?) }
    thread
  end

  def waiting_on_lock?(pid)
    ActiveRecord::Base.uncached do
      ActiveRecord::Base.with_connection { |connection| connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0") }
    end
  end

  let(:book) { Book.find_by!(serial_number: "000001") }
  let(:ada) { Reader.find_by!(card_number: "100001") }

  before do
    delete_all_rows
    create(:book, serial_number: "000001", title: "Dune", author: "Frank Herbert")
    create(:reader, card_number: "100001")
    create(:reader, card_number: "100002")
  end

  it "lets only one of two readers borrow the same book" do
    second = nil

    ActiveRecord::Base.transaction do
      Circulation::BorrowBook.call(serial_number: "000001", card_number: "100001")
      second = start_waiting_for_lock { Circulation::BorrowBook.call(serial_number: "000001", card_number: "100002") }
    end

    expect { second.value }.to raise_error(Circulation::BookBorrowed)
    expect(Borrowing.active.sole.reader).to eq(ada)
  end

  it "makes a withdrawal wait for a borrow in flight, then refuse" do
    withdrawal = nil

    ActiveRecord::Base.transaction do
      Circulation::BorrowBook.call(serial_number: "000001", card_number: "100001")
      withdrawal = start_waiting_for_lock { Catalog::WithdrawBook.call(serial_number: "000001") }
    end

    expect { withdrawal.value }.to raise_error(Circulation::BookBorrowed)
    expect(book.reload.withdrawn_at).to be_nil
  end

  it "makes a borrow wait for a withdrawal in flight, then refuse the withdrawn book" do
    borrow = nil

    ActiveRecord::Base.transaction do
      Catalog::WithdrawBook.call(serial_number: "000001")
      borrow = start_waiting_for_lock { Circulation::BorrowBook.call(serial_number: "000001", card_number: "100001") }
    end

    expect { borrow.value }.to raise_error(Catalog::BookWithdrawn)
    expect(Borrowing.count).to eq(0)
  end

  it "keeps the first return time when the same borrowing is returned twice at once" do
    borrowing = Circulation::BorrowBook.call(serial_number: "000001", card_number: "100001", borrowed_at: 1.hour.ago)
    first_return = nil
    second = nil

    ActiveRecord::Base.transaction do
      first_return = Circulation::ReturnBook.call(borrowing_id: borrowing.id, returned_at: 10.minutes.ago).returned_at
      second = start_waiting_for_lock { Circulation::ReturnBook.call(borrowing_id: borrowing.id) }
    end

    expect(second.value.returned_at).to eq(first_return)
    expect(borrowing.reload.returned_at).to eq(first_return)
  end

  it "dates a borrow from when it gets the book, so it never starts before a return made while it waited" do
    earlier = Circulation::BorrowBook.call(serial_number: "000001", card_number: "100001", borrowed_at: 1.hour.ago)
    waiting_borrow = nil

    ActiveRecord::Base.transaction do
      Book.lock.find_by!(serial_number: "000001")
      waiting_borrow = start_waiting_for_lock { Circulation::BorrowBook.call(serial_number: "000001", card_number: "100002") }
      Circulation::ReturnBook.call(borrowing_id: earlier.id)
    end

    expect(waiting_borrow.value.borrowed_at).to be >= earlier.reload.returned_at
  end

  it "refuses the second of two identical adds" do
    second = nil

    ActiveRecord::Base.transaction do
      Catalog::AddBook.call(serial_number: "000002", title: "Solaris", author: "Stanisław Lem")
      second = start_waiting_for_lock { Catalog::AddBook.call(serial_number: "000002", title: "Solaris", author: "Stanisław Lem") }
    end

    expect { second.value }.to raise_error(Catalog::AddBook::SerialNumberTaken)
    expect(Book.where(serial_number: "000002").count).to eq(1)
  end

  it "refuses the second of two identical registrations" do
    second = nil

    ActiveRecord::Base.transaction do
      Membership::RegisterReader.call(card_number: "100003", full_name: "Grace Hopper", email: "grace@example.com")
      second = start_waiting_for_lock { Membership::RegisterReader.call(card_number: "100003", full_name: "Grace Hopper", email: "grace@example.com") }
    end

    expect { second.value }.to raise_error(Membership::RegisterReader::CardNumberTaken)
    expect(Reader.where(card_number: "100003").count).to eq(1)
  end

  it "refuses the second of two registrations with the same email" do
    second = nil

    ActiveRecord::Base.transaction do
      Membership::RegisterReader.call(card_number: "100003", full_name: "Grace Hopper", email: "grace@example.com")
      second = start_waiting_for_lock { Membership::RegisterReader.call(card_number: "100004", full_name: "Grace H.", email: "grace@example.com") }
    end

    expect { second.value }.to raise_error(Membership::RegisterReader::EmailTaken)
  end
end
