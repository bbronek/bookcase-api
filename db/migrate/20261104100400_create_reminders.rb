class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :reminders do |t|
      t.references :borrowing, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.datetime :sent_at
      t.timestamps

      # One reminder of each kind per borrowing: makes the daily job idempotent and leaves an audit trail.
      t.index [ :borrowing_id, :kind ], unique: true
    end
  end
end
