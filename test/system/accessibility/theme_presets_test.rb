# frozen_string_literal: true

require "application_system_test_case"

# Ensures each theme’s CSS variables produce sufficient contrast on real app chrome.
class AccessibilityThemePresetsTest < ApplicationSystemTestCase
  test "parent dashboard for each theme preset" do
    ThemeManager::PRESETS.each_key do |theme_key|
      Capybara.reset_sessions!
      parent = create_parent_for_system(email: "theme-#{theme_key}-#{SecureRandom.hex(4)}@example.com")
      parent.update!(current_theme: theme_key)
      sign_in_via_ui(parent)
      assert_current_path parent_dashboard_path
      assert_no_accessibility_violations
    end
  end
end
