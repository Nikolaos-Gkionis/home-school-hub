# frozen_string_literal: true

require "test_helper"

class ParentTimetableTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Date.new(2026, 9, 14)
    @parent = User.create!(
      email: "parent-timetable@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @parent.learners.create!(year_group_key: "year_7")
    @parent.update!(active_learner: @parent.learners.first)

    @child = User.create!(
      email: "parent-timetable-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7", display_label: "Sam")
    @child.update!(active_learner: @child.learners.first)

    @english = Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: "Autumn stories",
      unit_position: 1,
      title: "Lesson A",
      external_url: "https://www.thenational.academy/pupils/lessons/parent-timetable-autumn",
      oak_lesson_slug: "parent-timetable-autumn",
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

  test "parent family dashboard still loads without a view param" do
    sign_in_parent
    get parent_dashboard_path

    assert_response :success
    assert_includes response.body, "Family dashboard"
    assert_not_includes response.body, "school day"
  end

  test "parent day timetable mirrors the child's year plan" do
    sign_in_parent
    get parent_dashboard_path(view: "day", child_id: @child.id)

    assert_response :success
    assert_includes response.body, "Sam"
    assert_includes response.body, "school day"
    assert_includes response.body, "Hour 1"
    assert_includes response.body, @english.title
    assert_includes response.body, "Week"
  end

  test "parent week timetable mirrors the child's year plan" do
    sign_in_parent
    get parent_dashboard_path(view: "week", child_id: @child.id)

    assert_response :success
    assert_includes response.body, "This week"
    assert_includes response.body, "Sam"
    assert_includes response.body, "Mon"
    assert_includes response.body, "09:00"
    assert_includes response.body, "Lunch"
    assert_includes response.body, @english.title
  end

  test "parent day does not use the parent account's own empty plan" do
    @parent.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "Mathematics",
      unit: "Number"
    )
    maths = Lesson.create!(
      year_group_key: "year_7",
      subject: "Mathematics",
      unit: "Number",
      unit_position: 1,
      title: "Parent-only maths",
      external_url: "https://www.thenational.academy/pupils/lessons/parent-only-maths",
      oak_lesson_slug: "parent-only-maths",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )

    sign_in_parent
    get parent_dashboard_path(view: "day", child_id: @child.id)

    assert_select "#school-day-timeline", text: /#{Regexp.escape(@english.title)}/
    assert_select "#school-day-timeline", text: /#{Regexp.escape(maths.title)}/, count: 0
  end

  test "parent without children is asked to invite one" do
    lone = User.create!(
      email: "parent-no-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    post user_session_path, params: {
      user: { email: lone.email, password: "Password123!" }
    }
    get parent_dashboard_path(view: "day")

    assert_response :success
    assert_includes response.body, "No child to preview yet"
    assert_not_includes response.body, "Your school day"
  end

  test "parent can open a lesson from the child's timetable" do
    sign_in_parent
    get parent_dashboard_path(lesson_id: @english.id, child_id: @child.id)

    assert_response :success
    assert_includes response.body, @english.title
    assert_not_includes response.body, "Family dashboard"
  end

  private

  def sign_in_parent
    post user_session_path, params: {
      user: { email: @parent.email, password: "Password123!" }
    }
  end
end
