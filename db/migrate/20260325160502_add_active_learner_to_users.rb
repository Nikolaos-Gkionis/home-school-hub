class AddActiveLearnerToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :active_learner, null: true, foreign_key: { to_table: :learners }
  end
end
