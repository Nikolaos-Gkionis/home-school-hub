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

  test "parent insights includes daily learner breakdown and totals" do
    parent = User.create!(
      email: "insights-parent-#{SecureRandom.hex(4)}@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      role: User::ROLE_PARENT
    )
    child_one = User.create!(
      email: "insights-child-one-#{SecureRandom.hex(4)}@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      role: User::ROLE_LEARNER,
      parent_id: parent.id
    )
    child_two = User.create!(
      email: "insights-child-two-#{SecureRandom.hex(4)}@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      role: User::ROLE_LEARNER,
      parent_id: parent.id
    )
    lesson = Lesson.create!(
      year_group_key: "year_8",
      subject: "Science",
      unit: "Unit B",
      title: "Insights daily lesson",
      external_url: "https://www.thenational.academy/pupils/lessons/insights-daily",
      oak_lesson_slug: "insights-daily-#{SecureRandom.hex(4)}",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
    lesson_two = Lesson.create!(
      year_group_key: "year_8",
      subject: "Science",
      unit: "Unit C",
      title: "Insights daily lesson two",
      external_url: "https://www.thenational.academy/pupils/lessons/insights-daily-two",
      oak_lesson_slug: "insights-daily-two-#{SecureRandom.hex(4)}",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 2
    )

    day_one = Date.new(2026, 4, 20)
    day_two = Date.new(2026, 4, 21)
    LessonCompletion.create!(user: child_one, lesson: lesson, completed_at: day_one.noon)
    LessonCompletion.create!(user: child_one, lesson: lesson_two, completed_at: day_two.noon)
    LessonCompletion.create!(user: child_two, lesson: lesson, completed_at: day_two.noon)
    LessonTimeLog.create!(user: child_one, lesson: lesson, logged_on: day_one, seconds: 120)
    LessonTimeLog.create!(user: child_one, lesson: lesson_two, logged_on: day_two, seconds: 180)
    LessonTimeLog.create!(user: child_two, lesson: lesson, logged_on: day_two, seconds: 60)

    metrics = Insights::Summary.call(viewer: parent, scope_user: nil)

    assert_equal [ day_one.to_s, day_two.to_s ], metrics[:daily_lesson_dates]
    row_one = metrics[:daily_lesson_rows].find { |row| row[:user_id] == child_one.id }
    row_two = metrics[:daily_lesson_rows].find { |row| row[:user_id] == child_two.id }

    assert_equal 1, row_one[:by_date][day_one.to_s]
    assert_equal 1, row_one[:by_date][day_two.to_s]
    assert_equal 2, row_one[:total]
    assert_equal 0, row_two[:by_date][day_one.to_s]
    assert_equal 1, row_two[:by_date][day_two.to_s]
    assert_equal 1, row_two[:total]
    assert_equal 1, metrics[:daily_lesson_totals][day_one.to_s]
    assert_equal 2, metrics[:daily_lesson_totals][day_two.to_s]

    assert_equal [ day_one.to_s, day_two.to_s ], metrics[:daily_time_dates]
    time_row_one = metrics[:daily_time_rows].find { |row| row[:user_id] == child_one.id }
    time_row_two = metrics[:daily_time_rows].find { |row| row[:user_id] == child_two.id }

    assert_equal 2.0, time_row_one[:by_date][day_one.to_s]
    assert_equal 3.0, time_row_one[:by_date][day_two.to_s]
    assert_equal 5.0, time_row_one[:total]
    assert_equal 0.0, time_row_two[:by_date][day_one.to_s]
    assert_equal 1.0, time_row_two[:by_date][day_two.to_s]
    assert_equal 1.0, time_row_two[:total]
    assert_equal 2.0, metrics[:daily_time_totals][day_one.to_s]
    assert_equal 4.0, metrics[:daily_time_totals][day_two.to_s]
  end

  test "multiple sessions on the same day aggregate into one daily column" do
    parent = User.create!(
      email: "insights-parent-#{SecureRandom.hex(4)}@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      role: User::ROLE_PARENT
    )
    child = User.create!(
      email: "insights-child-#{SecureRandom.hex(4)}@example.com",
      password: "password123456",
      password_confirmation: "password123456",
      role: User::ROLE_LEARNER,
      parent_id: parent.id
    )
    lessons = 3.times.map do |idx|
      Lesson.create!(
        year_group_key: "year_8",
        subject: "Science",
        unit: "Unit #{idx}",
        title: "Same-day lesson #{idx}",
        external_url: "https://www.thenational.academy/pupils/lessons/same-day-#{idx}",
        oak_lesson_slug: "same-day-#{SecureRandom.hex(4)}",
        content_mode: Lesson::CONTENT_MODE_OAK_HUB,
        position: idx + 1
      )
    end

    day = Date.new(2026, 6, 7)
    lessons.each_with_index do |lesson, idx|
      LessonCompletion.create!(user: child, lesson:, completed_at: day.to_time.change(hour: 9 + idx))
      LessonTimeLog.create!(user: child, lesson:, logged_on: day, seconds: 60 * (idx + 1))
    end

    metrics = Insights::Summary.call(viewer: parent, scope_user: child)

    assert_equal [ day.to_s ], metrics[:daily_lesson_dates]
    assert_equal 3, metrics[:daily_lesson_rows].sole[:by_date][day.to_s]
    assert_equal 3, metrics[:daily_lesson_totals][day.to_s]

    assert_equal [ day.to_s ], metrics[:daily_time_dates]
    assert_equal 6.0, metrics[:daily_time_rows].sole[:by_date][day.to_s]
    assert_equal 6.0, metrics[:daily_time_totals][day.to_s]
  end
end
