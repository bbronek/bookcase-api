class CreateReaders < ActiveRecord::Migration[8.1]
  def change
    create_table :readers, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :card_number, null: false
      t.string :full_name, null: false, limit: 255
      t.string :email, null: false, limit: 254
      t.timestamps

      t.index :card_number, unique: true
      t.index :email, unique: true
      t.check_constraint "card_number ~ '^[0-9]{6}$'", name: "readers_card_number_six_digits"
      t.check_constraint "full_name ~ '[^[:space:]]' AND full_name !~ '[[:cntrl:]]'",
        name: "readers_full_name_plain_text"
      t.check_constraint "email = lower(btrim(email))", name: "readers_email_normalized"
    end
  end
end
