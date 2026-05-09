# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_09_083000) do
  create_table "badges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_badges_on_key", unique: true
  end

  create_table "checkpoint_tests", force: :cascade do |t|
    t.integer "child_id", null: false
    t.integer "completed_lessons_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "parent_id", null: false
    t.integer "question_count", default: 0, null: false
    t.json "questions_json", default: [], null: false
    t.string "subject", null: false
    t.json "units_json", default: [], null: false
    t.datetime "updated_at", null: false
    t.index ["child_id", "subject", "created_at"], name: "index_checkpoint_tests_on_child_id_and_subject_and_created_at"
    t.index ["child_id"], name: "index_checkpoint_tests_on_child_id"
    t.index ["parent_id"], name: "index_checkpoint_tests_on_parent_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.string "child_name"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.integer "parent_id", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "year_group_key", null: false
    t.index ["parent_id", "email"], name: "index_invitations_pending_unique", unique: true, where: "accepted_at IS NULL"
    t.index ["parent_id"], name: "index_invitations_on_parent_id"
    t.index ["token"], name: "index_invitations_on_token", unique: true
  end

  create_table "learners", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_label"
    t.integer "position", default: 0, null: false
    t.json "preferred_subjects"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.string "year_group_key", null: false
    t.index ["user_id", "year_group_key"], name: "index_learners_on_user_id_and_year_group_key"
    t.index ["user_id"], name: "index_learners_on_user_id"
  end

  create_table "lesson_completions", force: :cascade do |t|
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.integer "lesson_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["lesson_id"], name: "index_lesson_completions_on_lesson_id"
    t.index ["user_id", "lesson_id"], name: "index_lesson_completions_on_user_id_and_lesson_id", unique: true
    t.index ["user_id"], name: "index_lesson_completions_on_user_id"
  end

  create_table "lesson_quiz_responses", force: :cascade do |t|
    t.json "answer_indices", default: [], null: false
    t.boolean "correct", null: false
    t.datetime "created_at", null: false
    t.integer "lesson_id", null: false
    t.integer "question_index", null: false
    t.string "quiz_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["lesson_id"], name: "index_lesson_quiz_responses_on_lesson_id"
    t.index ["user_id", "lesson_id", "quiz_type", "question_index"], name: "idx_lesson_quiz_responses_unique", unique: true
    t.index ["user_id"], name: "index_lesson_quiz_responses_on_user_id"
  end

  create_table "lesson_section_views", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.integer "lesson_id", null: false
    t.string "section_key", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["lesson_id"], name: "index_lesson_section_views_on_lesson_id"
    t.index ["user_id", "lesson_id", "section_key"], name: "idx_lesson_section_views_unique", unique: true
    t.index ["user_id"], name: "index_lesson_section_views_on_user_id"
  end

  create_table "lesson_time_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "lesson_id", null: false
    t.date "logged_on", null: false
    t.integer "seconds", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["lesson_id"], name: "index_lesson_time_logs_on_lesson_id"
    t.index ["user_id", "lesson_id", "logged_on"], name: "index_lesson_time_logs_daily_unique", unique: true
    t.index ["user_id"], name: "index_lesson_time_logs_on_user_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.json "assets_json", default: {}, null: false
    t.string "content_mode", default: "legacy_iframe", null: false
    t.datetime "created_at", null: false
    t.string "external_url", null: false
    t.string "oak_key_stage_slug"
    t.string "oak_lesson_slug"
    t.string "oak_subject_slug"
    t.datetime "oak_synced_at"
    t.integer "position", default: 0, null: false
    t.json "quizzes_json", default: {}, null: false
    t.string "subject", null: false
    t.json "summary_json", default: {}, null: false
    t.string "title", null: false
    t.json "transcript_json", default: {}, null: false
    t.string "unit", null: false
    t.integer "unit_position"
    t.datetime "updated_at", null: false
    t.string "year_group_key", default: "year_7", null: false
    t.index ["subject", "unit", "position"], name: "index_lessons_on_subject_and_unit_and_position"
    t.index ["year_group_key", "oak_lesson_slug"], name: "index_lessons_on_year_group_key_and_oak_lesson_slug", unique: true, where: "oak_lesson_slug IS NOT NULL"
    t.index ["year_group_key", "subject", "unit", "position"], name: "index_lessons_on_year_subject_unit_position"
    t.index ["year_group_key", "subject", "unit_position"], name: "index_lessons_on_year_subject_unit_position_order"
  end

  create_table "user_badges", force: :cascade do |t|
    t.datetime "awarded_at", null: false
    t.integer "badge_id", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.string "scope_key"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["badge_id"], name: "index_user_badges_on_badge_id"
    t.index ["user_id", "badge_id", "scope_key"], name: "index_user_badges_unique_award", unique: true
    t.index ["user_id"], name: "index_user_badges_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "active_learner_id"
    t.datetime "created_at", null: false
    t.string "current_theme", default: "cosmic_voyager", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "last_active_lesson_id"
    t.integer "last_completed_lesson_id"
    t.integer "parent_id"
    t.json "preferred_subjects"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "parent", null: false
    t.datetime "setup_completed_at"
    t.json "sidebar_expanded", default: {"phases" => [], "years" => [], "subjects" => [], "units" => []}, null: false
    t.datetime "updated_at", null: false
    t.index ["active_learner_id"], name: "index_users_on_active_learner_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_active_lesson_id"], name: "index_users_on_last_active_lesson_id"
    t.index ["last_completed_lesson_id"], name: "index_users_on_last_completed_lesson_id"
    t.index ["parent_id"], name: "index_users_on_parent_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "checkpoint_tests", "users", column: "child_id"
  add_foreign_key "checkpoint_tests", "users", column: "parent_id"
  add_foreign_key "invitations", "users", column: "parent_id"
  add_foreign_key "learners", "users"
  add_foreign_key "lesson_completions", "lessons"
  add_foreign_key "lesson_completions", "users"
  add_foreign_key "lesson_quiz_responses", "lessons"
  add_foreign_key "lesson_quiz_responses", "users"
  add_foreign_key "lesson_section_views", "lessons"
  add_foreign_key "lesson_section_views", "users"
  add_foreign_key "lesson_time_logs", "lessons"
  add_foreign_key "lesson_time_logs", "users"
  add_foreign_key "user_badges", "badges"
  add_foreign_key "user_badges", "users"
  add_foreign_key "users", "learners", column: "active_learner_id"
  add_foreign_key "users", "lessons", column: "last_active_lesson_id"
  add_foreign_key "users", "lessons", column: "last_completed_lesson_id"
  add_foreign_key "users", "users", column: "parent_id"
end
