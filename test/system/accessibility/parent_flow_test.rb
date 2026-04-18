# frozen_string_literal: true

require "application_system_test_case"

class AccessibilityParentFlowTest < ApplicationSystemTestCase
  test "parent dashboard and family area" do
    parent = create_parent_for_system
    sign_in_via_ui(parent)
    assert_current_path parent_dashboard_path
    assert_no_accessibility_violations

    visit parent_family_path
    assert_no_accessibility_violations
  end

  test "new invitation form" do
    parent = create_parent_for_system(email: "parent-invite-a11y@example.com")
    sign_in_via_ui(parent)
    visit new_invitation_path
    assert_no_accessibility_violations
  end
end
