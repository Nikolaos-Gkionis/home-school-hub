# frozen_string_literal: true

require "test_helper"

class PwaTest < ActionDispatch::IntegrationTest
  def test_manifest_describes_an_installable_app
    get "/manifest.json"

    assert_response :success
    manifest = JSON.parse(response.body)

    assert_equal "HomeSchool Hub", manifest["name"]
    assert_equal "standalone", manifest["display"]
    assert_equal "/", manifest["start_url"]
    assert_equal "#0f766e", manifest["theme_color"]
    assert(manifest["icons"].any? { |icon| icon["sizes"] == "192x192" })
    assert(manifest["icons"].any? { |icon| icon["sizes"] == "512x512" })
  end

  def test_service_worker_handles_fetch
    get "/service-worker"

    assert_response :success
    assert_includes response.body, "addEventListener(\"fetch\""
  end

  def test_landing_page_links_manifest_and_graduate_hat_icon
    get root_path

    assert_response :success
    assert_select "link[rel='manifest']"
    assert_select "link[rel='icon'][href='/icon.svg']"
    assert_select "link[rel='apple-touch-icon'][href='/icon.png']"
  end

  def test_sign_in_page_links_manifest
    get new_user_session_path

    assert_response :success
    assert_select "link[rel='manifest']"
    assert_select "link[rel='icon'][href='/icon.svg']"
  end

  def test_signed_in_app_layout_links_manifest
    parent = User.create!(
      email: "pwa-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    parent.learners.create!(year_group_key: Curriculum::YearGroups.all_year_keys.first)
    parent.update!(active_learner: parent.learners.first)

    post user_session_path, params: {
      user: { email: parent.email, password: "Password123!" }
    }
    get parent_dashboard_path

    assert_response :success
    assert_select "link[rel='manifest']"
    assert_select "link[rel='icon'][href='/icon.svg']"
  end

  def test_favicon_svg_is_the_graduate_hat_not_the_red_rails_circle
    get "/icon.svg"

    assert_response :success
    assert_includes response.body, "#0f766e"
    assert_not_includes response.body, 'fill="red"'
  end
end
