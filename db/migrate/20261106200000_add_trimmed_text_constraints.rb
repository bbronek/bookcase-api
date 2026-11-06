class AddTrimmedTextConstraints < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :books, "title = btrim(title)", name: "books_title_trimmed"
    add_check_constraint :books, "author = btrim(author)", name: "books_author_trimmed"
    add_check_constraint :readers, "full_name = btrim(full_name)", name: "readers_full_name_trimmed"
  end
end
