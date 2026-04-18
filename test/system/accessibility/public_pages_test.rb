# frozen_string_literal: true

require "application_system_test_case"

class AccessibilityPublicPagesTest < ApplicationSystemTestCase
  test "marketing home is accessible (axe runs after visit)" do
    visit root_path
    assert_no_accessibility_violations
  end

  test "sign in page is accessible" do
    visit new_user_session_path
    assert_no_accessibility_violations
  end

  test "sign up page is accessible" do
    visit new_user_registration_path
    assert_no_accessibility_violations
  end
end
