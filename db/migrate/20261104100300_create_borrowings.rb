class CreateBorrowings < ActiveRecord::Migration[8.1]
  def change
    create_table :borrowings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :book, type: :uuid, null: false, foreign_key: true, index: false
      t.references :reader, type: :uuid, null: false, foreign_key: true
      t.datetime :borrowed_at, null: false
      t.date :due_on, null: false
      t.datetime :returned_at
      t.timestamps

      t.index %i[ book_id borrowed_at id ], order: { borrowed_at: :desc, id: :desc },
        name: "index_borrowings_on_book_history"
      t.index :book_id, unique: true, where: "returned_at IS NULL", name: "index_borrowings_on_active_book"
      t.index :due_on, where: "returned_at IS NULL", name: "index_borrowings_on_due_on_active"
      t.check_constraint "returned_at IS NULL OR returned_at >= borrowed_at", name: "borrowings_returned_after_borrowed"
      t.check_constraint "due_on > (borrowed_at AT TIME ZONE 'Europe/Warsaw')::date",
        name: "borrowings_due_after_borrowed"
    end
  end
end
