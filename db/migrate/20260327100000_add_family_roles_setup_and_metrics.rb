# frozen_string_literal: true

class AddFamilyRolesSetupAndMetrics < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :string, null: false, default: "parent"
    add_reference :users, :parent, foreign_key: { to_table: :users }, null: true
    add_column :users, :setup_completed_at, :datetime

    add_index :users, :role

    add_column :learners, :preferred_subjects, :json, default: nil

    create_table :invitations do |t|
      t.references :parent, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :token, null: false
      t.string :year_group_key, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, [ :parent_id, :email ], unique: true, where: "accepted_at IS NULL", name: "index_invitations_pending_unique"

    create_table :lesson_time_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :lesson, null: false, foreign_key: true
      t.integer :seconds, null: false, default: 0
      t.date :logged_on, null: false
      t.timestamps
    end

    add_index :lesson_time_logs, [ :user_id, :lesson_id, :logged_on ], unique: true, name: "index_lesson_time_logs_daily_unique"
  end
end
