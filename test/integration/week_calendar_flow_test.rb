# frozen_string_literal: true

require "test_helper"

class WeekCalendarFlowTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Date.new(2026, 9, 15)
    @parent = User.create!(
      email: "week-flow-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @child = User.create!(
      email: "week-flow-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7")
    @child.update!(active_learner: @child.learners.first)

    @lesson = Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: "Autumn stories",
      unit_position: 1,
      title: "Lesson A",
      external_url: "https://www.thenational.academy/pupils/lessons/autumn-stories",
      oak_lesson_slug: "autumn-stories",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "English",
      unit: "Autumn stories"
    )
  end

  test "child can open this week from the dashboard" do
    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(overview: "week")

    assert_response :success
    assert_includes response.body, "This week"
    assert_includes response.body, "timetable"
    assert_includes response.body, "Lesson A"
    assert_includes response.body, "09:00"
    assert_includes response.body, "Lunch"
    assert_includes response.body, "Comfort break"
    assert_includes response.body, "Autumn stories"
    assert_includes response.body, "Print week"
    assert_includes response.body, child_dashboard_path(lesson_id: @lesson.id)
  end

  test "parent can open the weekly calendar for a child" do
    post user_session_path, params: {
      user: { email: @parent.email, password: "Password123!" }
    }
    get parent_child_week_path(@child)

    assert_response :success
    assert_includes response.body, "weekly calendar"
    assert_includes response.body, "Lesson A"
    assert_includes response.body, "Year plan"
    assert_includes response.body, "Print week"
    assert_includes response.body, @lesson.oak_pupil_lesson_url
  end

  test "parent can swap two lesson blocks" do
    extra = Lesson.create!(
      year_group_key: "year_7",
      subject: "Mathematics",
      unit: "Numbers",
      unit_position: 1,
      title: "Lesson B",
      external_url: "https://www.thenational.academy/pupils/lessons/numbers",
      oak_lesson_slug: "numbers",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "Mathematics",
      unit: "Numbers"
    )

    post user_session_path, params: {
      user: { email: @parent.email, password: "Password123!" }
    }
    result = Curriculum::WeekCalendar.call(child: @child, month: 9, week_monday: Date.new(2026, 9, 14))
    taught = result.selected_week.slots.select { |slot| slot.lesson }
    first, second = taught.first(2)
    assert first && second, "expected two taught slots, got #{taught.size}"

    post swap_week_slot_path, params: {
      child_id: @child.id,
      month: 9,
      week: "2026-09-14",
      from_date: first.date,
      from_period: first.period.key,
      to_date: second.date,
      to_period: second.period.key
    }
    assert_redirected_to parent_child_week_path(@child, month: 9, week: "2026-09-14")

    moved = Curriculum::WeekCalendar.call(child: @child, month: 9, week_monday: Date.new(2026, 9, 14))
    assert_equal second.lesson.id, moved.slot_at(first.date, first.period).lesson.id
    assert_equal first.lesson.id, moved.slot_at(second.date, second.period).lesson.id
    assert_includes [ @lesson.id, extra.id ], first.lesson.id
  end

  test "child cannot browse a locked future month" do
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 10,
      subject: "English",
      unit: "Winter poems"
    )
    Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: "Winter poems",
      unit_position: 2,
      title: "Future lesson",
      external_url: "https://www.thenational.academy/pupils/lessons/winter-poems",
      oak_lesson_slug: "winter-poems",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )

    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(overview: "week", month: 10)

    assert_response :success
    assert_includes response.body, "September timetable"
    assert_not_includes response.body, "Future lesson"
  end
end
