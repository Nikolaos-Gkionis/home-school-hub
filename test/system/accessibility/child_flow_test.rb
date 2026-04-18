# frozen_string_literal: true

require "application_system_test_case"

class AccessibilityChildFlowTest < ApplicationSystemTestCase
  test "child dashboard and profile" do
    parent = create_parent_for_system(email: "parent-for-child-a11y@example.com")
    child = create_child_for_system(parent: parent, email: "child-a11y-flow@example.com")
    sign_in_via_ui(child)
    assert_current_path child_dashboard_path
    assert_no_accessibility_violations

    visit child_profile_path
    assert_no_accessibility_violations
  end
end
