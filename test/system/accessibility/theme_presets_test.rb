# frozen_string_literal: true

require "application_system_test_case"

# Ensures the academy theme’s CSS variables produce sufficient contrast on real app chrome.
class AccessibilityThemePresetsTest < ApplicationSystemTestCase
  test "parent dashboard for academy theme" do
    parent = create_parent_for_system(email: "theme-academy-#{SecureRandom.hex(4)}@example.com")
    parent.update!(current_theme: ThemeManager::CANONICAL)
    sign_in_via_ui(parent)
    assert_current_path parent_dashboard_path
    assert_no_accessibility_violations
  end
end
