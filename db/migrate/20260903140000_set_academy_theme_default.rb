# frozen_string_literal: true

class SetAcademyThemeDefault < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :current_theme, from: "cosmic_voyager", to: "academy"
    execute <<~SQL.squish
      UPDATE users
      SET current_theme = 'academy'
      WHERE current_theme IS NULL
         OR current_theme != 'academy'
    SQL
  end

  def down
    change_column_default :users, :current_theme, from: "academy", to: "cosmic_voyager"
  end
end
