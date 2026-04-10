# frozen_string_literal: true

class AddUnitPositionToLessons < ActiveRecord::Migration[8.1]
  def change
    add_column :lessons, :unit_position, :integer
    add_index :lessons, %i[year_group_key subject unit_position],
              name: "index_lessons_on_year_subject_unit_position_order"
  end
end
