class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :serial_number, null: false
      t.string :title, null: false, limit: 255
      t.string :author, null: false, limit: 255
      t.datetime :withdrawn_at
      t.timestamps

      t.index :serial_number, unique: true
      t.check_constraint "serial_number ~ '^[0-9]{6}$'", name: "books_serial_number_six_digits"
      t.check_constraint "title ~ '[^[:space:]]' AND title !~ '[[:cntrl:]]'", name: "books_title_plain_text"
      t.check_constraint "author ~ '[^[:space:]]' AND author !~ '[[:cntrl:]]'", name: "books_author_plain_text"
    end
  end
end
