class CreateBadges < ActiveRecord::Migration[8.1]
  def change
    create_table :badges do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :badges, :key, unique: true
  end
end
