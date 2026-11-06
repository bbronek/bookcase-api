class AddReaderEmailShapeConstraint < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :readers,
      "email ~ '^[^@[:space:]]+@[^@[:space:]]+$' AND email !~ '[[:cntrl:]]'",
      name: "readers_email_shape"
  end
end
