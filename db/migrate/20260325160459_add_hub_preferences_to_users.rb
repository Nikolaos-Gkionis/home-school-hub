class AddHubPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :current_theme, :string, null: false, default: "cosmic_voyager"
    add_column :users, :preferred_subjects, :json
    add_column :users, :sidebar_expanded, :json, null: false, default: { "phases" => [], "years" => [], "subjects" => [], "units" => [] }
    add_reference :users, :last_active_lesson, null: true, foreign_key: { to_table: :lessons }
    add_reference :users, :last_completed_lesson, null: true, foreign_key: { to_table: :lessons }
  end
end
