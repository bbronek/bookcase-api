class SimplifyBorrowingAndReminderGuards < ActiveRecord::Migration[8.1]
  def up
    add_index :borrowings, :book_id, unique: true, where: "returned_at IS NULL",
      name: "index_borrowings_on_active_book"
    remove_exclusion_constraint :borrowings, name: "borrowings_of_a_book_never_overlap"
    disable_extension "btree_gist"
    remove_check_constraint :reminders, name: "reminders_sent_or_failed"
    remove_column :reminders, :failed_at
  end

  def down
    add_column :reminders, :failed_at, :timestamptz
    add_check_constraint :reminders, "sent_at IS NULL OR failed_at IS NULL", name: "reminders_sent_or_failed"
    enable_extension "btree_gist"
    add_exclusion_constraint :borrowings, "book_id WITH =, tstzrange(borrowed_at, returned_at) WITH &&",
      using: :gist, name: "borrowings_of_a_book_never_overlap"
    remove_index :borrowings, name: "index_borrowings_on_active_book"
  end
end
