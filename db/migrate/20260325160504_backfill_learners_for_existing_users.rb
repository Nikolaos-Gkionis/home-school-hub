class BackfillLearnersForExistingUsers < ActiveRecord::Migration[8.1]
  def up
    User.find_each do |user|
      next if user.learners.any?

      learner = user.learners.create!(year_group_key: "year_7", position: 0)
      user.update_column(:active_learner_id, learner.id)
    end
  end

  def down
    User.update_all(active_learner_id: nil)
    Learner.delete_all
  end
end
