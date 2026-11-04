class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings do |t|
      t.references :book, null: false, foreign_key: true
      t.references :reader, null: false, foreign_key: true
      t.datetime :borrowed_at, null: false
      t.date :due_on, null: false
      t.datetime :returned_at
      t.timestamps

      # The invariant "a book has at most one active borrowing" lives in the database,
      # so two concurrent borrow requests cannot both succeed regardless of application code.
      t.index :book_id, unique: true, where: "returned_at IS NULL", name: "index_borrowings_one_active_per_book"
      # Daily reminder scan: active borrowings due on a given date.
      t.index :due_on, where: "returned_at IS NULL", name: "index_borrowings_active_by_due_on"
      t.check_constraint "returned_at IS NULL OR returned_at >= borrowed_at", name: "borrowings_returned_after_borrowed"
    end
  end
end
