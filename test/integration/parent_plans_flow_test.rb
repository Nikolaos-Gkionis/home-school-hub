# frozen_string_literal: true

require "test_helper"

class ParentPlansFlowTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Date.new(2026, 9, 15)
    @parent = User.create!(
      email: "plans-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @parent.learners.create!(year_group_key: "year_7")
    @parent.update!(active_learner: @parent.learners.first)

    @child = User.create!(
      email: "plans-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7")
    @child.update!(active_learner: @child.learners.first)

    @sept = Lesson.create!(
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
    @oct = Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: "Winter poems",
      unit_position: 2,
      title: "Lesson B",
      external_url: "https://www.thenational.academy/pupils/lessons/winter-poems",
      oak_lesson_slug: "winter-poems",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
  end

  test "parent can assign a unit to september" do
    post user_session_path, params: {
      user: { email: @parent.email, password: "Password123!" }
    }
    get parent_child_plan_path(@child)
    assert_response :success
    assert_includes response.body, "Year plan"

    key = Lesson.compose_unit_key("English", "Autumn stories")
    patch parent_child_plan_path(@child), params: { month: 9, assigned_units: [ key ] }
    assert_redirected_to parent_child_plan_path(@child, month: 9)
    assert @child.unit_month_plans.exists?(month: 9, unit: "Autumn stories")
  end

  test "child cannot open a future month lesson by URL" do
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "English",
      unit: "Autumn stories"
    )
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 10,
      subject: "English",
      unit: "Winter poems"
    )

    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(lesson_id: @oct.id)
    assert_response :success
    assert_not_includes response.body, @oct.title
    assert_includes response.body, @sept.title
  end

  test "child with no plan can still open any lesson" do
    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(lesson_id: @oct.id)
    assert_response :success
    assert_includes response.body, @oct.title
  end
end
