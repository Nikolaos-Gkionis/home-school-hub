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

  def test_parent_family_page_shows_children_and_sent_invites
    parent = create_parent(email: "parent3@example.com")
    child = create_child(parent:, email: "child2@example.com")
    invite = parent.invitations.create!(
      child_name: "Pending Child",
      email: "pending.child@example.com",
      year_group_key: Curriculum::YearGroups.all_year_keys.first
    )

    sign_in_as(parent)
    get parent_family_path

    assert_response :success
    assert_includes response.body, child.email
    assert_includes response.body, invite.email
    assert_includes response.body, "Change year"
    assert_includes response.body, "Family"
  end

  def test_child_cannot_access_parent_family_page
    parent = create_parent(email: "parent4@example.com")
    child = create_child(parent:, email: "child3@example.com")

    sign_in_as(child)
    get parent_family_path

    assert_redirected_to child_dashboard_path
  end

  def test_parent_can_remove_child_account
    parent = create_parent(email: "parent6@example.com")
    child = create_child(parent:, email: "child-remove@example.com")

    sign_in_as(parent)
    delete parent_remove_child_path(child)

    assert_redirected_to parent_family_path
    child.reload
    assert_equal User::ROLE_PARENT, child.role
    assert_nil child.parent_id
  end

  def test_parent_can_edit_child_name_and_email
    parent = create_parent(email: "parent7@example.com")
    child = create_child(parent:, email: "child-edit@example.com")

    sign_in_as(parent)
    patch parent_update_child_path(child), params: {
      child: {
        child_name: "Updated Child Name",
        email: "updated-child@example.com",
        year_group_key: child.learners.first.year_group_key
      }
    }

    assert_redirected_to parent_family_path
    child.reload
    assert_equal "updated-child@example.com", child.email
    assert_equal "Updated Child Name", child.learners.order(:position).first.display_label
  end

  def test_parent_can_move_child_from_year_7_to_year_8
    parent = create_parent(email: "parent-year-move@example.com")
    child = create_child(parent:, email: "child-year-move@example.com", year_group_key: "year_7")

    sign_in_as(parent)
    patch parent_update_child_path(child), params: {
      child: {
        child_name: child.learners.first.display_name,
        email: child.email,
        year_group_key: "year_8"
      }
    }

    assert_redirected_to parent_family_path
    child.reload
    assert_equal [ "year_8" ], child.learner_year_keys
    assert_equal "year_8", child.active_learner.year_group_key
  end

  def test_child_can_activate_their_own_year
    parent = create_parent(email: "parent-activate@example.com")
    child = create_child(parent:, email: "child-activate@example.com", year_group_key: "year_7")
    year_eight = child.learners.create!(year_group_key: "year_8")

    sign_in_as(child)
    patch activate_learner_path(year_eight)

    assert_redirected_to child_dashboard_path
    child.reload
    assert_equal year_eight.id, child.active_learner_id
  end

  def test_child_cannot_add_a_school_year
    parent = create_parent(email: "parent-no-add-year@example.com")
    child = create_child(parent:, email: "child-no-add-year@example.com")

    sign_in_as(child)
    post learners_path, params: { year_group_key: "year_8" }

    assert_redirected_to child_dashboard_path
    assert_equal 1, child.learners.count
  end

  def test_parent_dashboard_shows_change_year_for_each_child
    parent = create_parent(email: "parent-dash-year@example.com")
    child = create_child(parent:, email: "child-dash-year@example.com", year_group_key: "year_7")

    sign_in_as(parent)
    get parent_dashboard_path

    assert_response :success
    assert_includes response.body, "Change year"
    assert_includes response.body, "Year 7"
    assert_includes response.body, parent_edit_child_path(child)
  end

  def test_child_can_switch_year_from_profile
    parent = create_parent(email: "parent-profile-year@example.com")
    child = create_child(parent:, email: "child-profile-year@example.com", year_group_key: "year_7")

    sign_in_as(child)
    get child_profile_path
    assert_response :success
    assert_includes response.body, "School year"
    assert_includes response.body, "Switch year"

    patch child_profile_path, params: { year_group_key: "year_8" }
    assert_redirected_to child_dashboard_path
    child.reload
    assert_equal "year_8", child.current_year_group_key
  end

  def test_invited_child_sign_up_links_parent_and_redirects_to_child_dashboard
    parent = create_parent(email: "parent5@example.com")
    invite = parent.invitations.create!(
      child_name: "New Child",
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

  def test_parent_can_edit_and_delete_pending_invite
    parent = create_parent(email: "parent8@example.com")
    invite = parent.invitations.create!(
      child_name: "Original Name",
      email: "invite-edit@example.com",
      year_group_key: Curriculum::YearGroups.all_year_keys.first
    )

    sign_in_as(parent)
    patch invitation_path(invite), params: {
      invitation: {
        child_name: "Edited Name",
        email: "invite-edited@example.com",
        year_group_key: invite.year_group_key
      }
    }
    assert_redirected_to parent_family_path

    invite.reload
    assert_equal "Edited Name", invite.child_name
    assert_equal "invite-edited@example.com", invite.email

    delete invitation_path(invite)
    assert_redirected_to parent_family_path
    assert_nil Invitation.find_by(id: invite.id)
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

  def create_child(parent:, email:, year_group_key: Curriculum::YearGroups.all_year_keys.first)
    child = User.create!(
      email:,
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent:,
      setup_completed_at: Time.current
    )
    child.learners.create!(year_group_key:)
    child.update!(active_learner: child.learners.first)
    child
  end

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "Password123!" }
    }
  end
end
