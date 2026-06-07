# frozen_string_literal: true

require "test_helper"

class InsightsDailyPaginationTest < ActionDispatch::IntegrationTest
  def test_insights_paginates_daily_columns_and_uses_short_date_labels
    parent = User.create!(
      email: "parent-daily-pages@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      role: User::ROLE_PARENT
    )
    child = User.create!(
      email: "child-daily-pages@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      role: User::ROLE_LEARNER,
      parent_id: parent.id
    )

    6.times do |idx|
      lesson = Lesson.create!(
        year_group_key: "year_8",
        subject: "Science",
        unit: "Unit #{idx}",
        title: "Paged lesson #{idx}",
        external_url: "https://example.com/paged/#{idx}",
        oak_lesson_slug: "paged-#{SecureRandom.hex(4)}",
        content_mode: Lesson::CONTENT_MODE_OAK_HUB,
        position: idx + 1
      )
      day = Date.new(2026, 6, 1) + idx.days
      LessonCompletion.create!(user: child, lesson:, completed_at: day.noon)
    end

    sign_in_as(parent)
    get insights_path

    assert_response :success
    assert_includes response.body, "page 1 of 2"
    assert_includes response.body, "2 Jun – 6 Jun"
    assert_includes response.body, 'href="/insights?daily_page=2">Older</a>'

    get insights_path, params: { daily_page: 2 }

    assert_response :success
    assert_includes response.body, "page 2 of 2"
    assert_includes response.body, "1 Jun"
    assert_includes response.body, 'href="/insights?daily_page=1">Newer</a>'
    assert_not_includes response.body, "title=\"2026-06-06\""
  end

  private

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password123456" }
    }
  end
end
