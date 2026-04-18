# frozen_string_literal: true

# Factories for system tests (same shape as integration tests; keeps parents/children setup-complete).
module SystemTestUsers
  def create_parent_for_system(email: "parent-system@example.com")
    parent = User.create!(
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    parent.learners.create!(year_group_key: Curriculum::YearGroups.all_year_keys.first)
    parent.update!(active_learner: parent.learners.first)
    parent
  end

  def create_child_for_system(parent:, email: "child-system@example.com")
    child = User.create!(
      email: email,
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: parent,
      setup_completed_at: Time.current
    )
    child.learners.create!(year_group_key: Curriculum::YearGroups.all_year_keys.first)
    child.update!(active_learner: child.learners.first)
    child
  end

  def sign_in_via_ui(user)
    visit new_user_session_path
    fill_in "user_email", with: user.email
    fill_in "user_password", with: "Password123!"
    click_button "Sign in"
  end
end
