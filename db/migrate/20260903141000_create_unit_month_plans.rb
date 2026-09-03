# frozen_string_literal: true

class CreateUnitMonthPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :unit_month_plans do |t|
      t.references :user, null: false, foreign_key: true
      t.string :year_group_key, null: false
      t.integer :academic_year, null: false
      t.integer :month, null: false
      t.string :subject, null: false
      t.string :unit, null: false
      t.timestamps
    end

    add_index :unit_month_plans,
      [ :user_id, :year_group_key, :academic_year, :subject, :unit ],
      unique: true,
      name: "index_unit_month_plans_unique_unit"
    add_index :unit_month_plans,
      [ :user_id, :year_group_key, :academic_year, :month ],
      name: "index_unit_month_plans_on_month"
  end
end
