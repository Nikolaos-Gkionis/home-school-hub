class AddYearGroupKeyToLessons < ActiveRecord::Migration[8.1]
  def change
    add_column :lessons, :year_group_key, :string, null: false, default: "year_7"
    add_index :lessons, [ :year_group_key, :subject, :unit, :position ], name: "index_lessons_on_year_subject_unit_position"
  end
end
