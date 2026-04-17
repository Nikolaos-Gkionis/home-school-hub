# frozen_string_literal: true

require "test_helper"

class RoleFlowsTest < ActionDispatch::IntegrationTest
  def test_parent_sign_in_routes_to_parent_dashboard
    parent = create_parent(email: "parent1@example.com")

    post user_session_path, params: {
      user: { email: parent.email, password: "Password123!" }
    }

    assert_redirected_to parent_dashboard_path
  end

  def test_child_sign_in_routes_to_child_dashboard
    parent = create_parent(email: "parent2@example.com")
    child = create_child(parent:, email: "child1@example.com")

    post user_session_path, params: {
      user: { email: child.email, password: "Password123!" }
    }

    assert_redirected_to child_dashboard_path
  end

  def test_parent_family_page_shows_children_and_pending_invites
    parent = create_parent(email: "parent3@example.com")
    child = create_child(parent:, email: "child2@example.com")
    invite = parent.invitations.create!(
      email: "pending.child@example.com",
      year_group_key: Curriculum::YearGroups.all_year_keys.first
    )

    sign_in_as(parent)
    get parent_family_path

    assert_response :success
    assert_includes response.body, child.email
    assert_includes response.body, invite.email
  end

  def test_child_cannot_access_parent_family_page
    parent = create_parent(email: "parent4@example.com")
    child = create_child(parent:, email: "child3@example.com")

    sign_in_as(child)
    get parent_family_path

    assert_redirected_to child_dashboard_path
  end

  def test_invited_child_sign_up_links_parent_and_redirects_to_child_dashboard
    parent = create_parent(email: "parent5@example.com")
    invite = parent.invitations.create!(
      email: "new.child@example.com",
      year_group_key: Curriculum::YearGroups.all_year_keys.first
    )

    post user_registration_path, params: {
      user: {
        email: invite.email,
        password: "Password123!",
        password_confirmation: "Password123!",
        invite_token: invite.token
      }
    }

    created_child = User.find_by(email: invite.email)
    assert_not_nil created_child
    assert created_child.learner?
    assert_equal parent.id, created_child.parent_id
    assert_redirected_to child_dashboard_path

    invite.reload
    assert_not_nil invite.accepted_at
  end

  private

  def create_parent(email:)
    parent = User.create!(
      email:,
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    parent.learners.create!(year_group_key: Curriculum::YearGroups.all_year_keys.first)
    parent.update!(active_learner: parent.learners.first)
    parent
  end

  def create_child(parent:, email:)
    child = User.create!(
      email:,
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent:,
      setup_completed_at: Time.current
    )
    child.learners.create!(year_group_key: Curriculum::YearGroups.all_year_keys.first)
    child.update!(active_learner: child.learners.first)
    child
  end

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "Password123!" }
    }
  end
end
