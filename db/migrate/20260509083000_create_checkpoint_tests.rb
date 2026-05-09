class CreateCheckpointTests < ActiveRecord::Migration[8.1]
  def change
    create_table :checkpoint_tests do |t|
      t.references :parent, null: false, foreign_key: { to_table: :users }
      t.references :child, null: false, foreign_key: { to_table: :users }
      t.string :subject, null: false
      t.integer :completed_lessons_count, null: false, default: 0
      t.integer :question_count, null: false, default: 0
      t.json :units_json, null: false, default: []
      t.json :questions_json, null: false, default: []

      t.timestamps
    end

    add_index :checkpoint_tests, [ :child_id, :subject, :created_at ]
  end
end
