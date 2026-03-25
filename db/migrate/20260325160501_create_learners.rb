class CreateLearners < ActiveRecord::Migration[8.1]
  def change
    create_table :learners do |t|
      t.references :user, null: false, foreign_key: true
      t.string :year_group_key, null: false
      t.string :display_label
      t.integer :position, default: 0, null: false

      t.timestamps
    end
    add_index :learners, [:user_id, :year_group_key]
  end
end
