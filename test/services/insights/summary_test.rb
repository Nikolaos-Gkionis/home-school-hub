# frozen_string_literal: true

require "test_helper"

class Insights::SummaryTest < ActiveSupport::TestCase
  test "parent with no child user accounts aggregates the parent account activity" do
    parent = User.create!(
      email: "insights-parent-#{SecureRandom.hex(4)}@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      role: User::ROLE_PARENT
    )
    lesson = Lesson.create!(
      year_group_key: "year_7",
      subject: "Maths",
      unit: "Unit A",
      title: "Insights test lesson",
      external_url: "https://www.thenational.academy/pupils/lessons/insights-test",
      oak_lesson_slug: "insights-test-#{SecureRandom.hex(4)}",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
    LessonCompletion.create!(user: parent, lesson: lesson, completed_at: Time.current)

    metrics = Insights::Summary.call(viewer: parent, scope_user: nil)

    assert_equal 1, metrics[:lessons_completed]
    assert_equal 1, metrics[:learner_count]
  end
end
