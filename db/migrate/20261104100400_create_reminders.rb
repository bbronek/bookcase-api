class CreateReminders < ActiveRecord::Migration[8.1]
  def change
    create_enum :reminder_kind, %w[ due_soon due_today ]

    create_table :reminders, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :borrowing, type: :uuid, null: false, foreign_key: true, index: false
      t.enum :kind, enum_type: :reminder_kind, null: false
      t.datetime :sent_at
      t.timestamps

      t.index %i[ borrowing_id kind ], unique: true
    end
  end
end
