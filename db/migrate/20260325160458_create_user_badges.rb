class CreateUserBadges < ActiveRecord::Migration[8.1]
  def change
    create_table :user_badges do |t|
      t.references :user, null: false, foreign_key: true
      t.references :badge, null: false, foreign_key: true
      t.datetime :awarded_at, null: false
      t.json :metadata, null: false, default: {}
      t.string :scope_key

      t.timestamps
    end
    add_index :user_badges, [:user_id, :badge_id, :scope_key], unique: true, name: "index_user_badges_unique_award"
  end
end
