# frozen_string_literal: true

class AddOakHubAndLessonProgress < ActiveRecord::Migration[8.1]
  def change
    change_table :lessons, bulk: true do |t|
      t.string :oak_lesson_slug
      t.string :oak_subject_slug
      t.string :oak_key_stage_slug
      t.string :content_mode, null: false, default: "legacy_iframe"
      t.json :summary_json, default: {}, null: false
      t.json :assets_json, default: {}, null: false
      t.json :quizzes_json, default: {}, null: false
    end

    add_index :lessons, [ :year_group_key, :oak_lesson_slug ], unique: true, where: "oak_lesson_slug IS NOT NULL"

    create_table :lesson_section_views do |t|
      t.references :user, null: false, foreign_key: true
      t.references :lesson, null: false, foreign_key: true
      t.string :section_key, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false
      t.timestamps
    end

    add_index :lesson_section_views, [ :user_id, :lesson_id, :section_key ], unique: true, name: "idx_lesson_section_views_unique"

    create_table :lesson_quiz_responses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :lesson, null: false, foreign_key: true
      t.string :quiz_type, null: false
      t.integer :question_index, null: false
      t.json :answer_indices, default: [], null: false
      t.boolean :correct, null: false
      t.timestamps
    end

    add_index :lesson_quiz_responses, [ :user_id, :lesson_id, :quiz_type, :question_index ],
              unique: true, name: "idx_lesson_quiz_responses_unique"
  end
end
