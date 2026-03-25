class CreateLessons < ActiveRecord::Migration[8.1]
  def change
    create_table :lessons do |t|
      t.string :title, null: false
      t.string :external_url, null: false
      t.string :subject, null: false
      t.string :unit, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end
    add_index :lessons, [:subject, :unit, :position]
  end
end
