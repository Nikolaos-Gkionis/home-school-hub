# frozen_string_literal: true

class CreateWeekLessonSlots < ActiveRecord::Migration[8.1]
  def change
    create_table :week_lesson_slots do |t|
      t.references :user, null: false, foreign_key: true
      t.references :lesson, foreign_key: true
      t.date :slot_date, null: false
      t.string :period_key, null: false
      t.timestamps
    end

    add_index :week_lesson_slots, [ :user_id, :slot_date, :period_key ],
      unique: true,
      name: "index_week_lesson_slots_unique_slot"
  end
end
