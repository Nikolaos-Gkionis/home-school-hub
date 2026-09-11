# frozen_string_literal: true

require "test_helper"

class ChildSchoolDayTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Date.new(2026, 9, 15)
    @parent = User.create!(
      email: "timetable-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @child = User.create!(
      email: "timetable-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7")
    @child.update!(active_learner: @child.learners.first)

    @english = Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: "Autumn stories",
      unit_position: 1,
      title: "Lesson A",
      external_url: "https://www.thenational.academy/pupils/lessons/timetable-autumn-stories",
      oak_lesson_slug: "timetable-autumn-stories",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
  end

  test "child dashboard without lesson_id renders the today timetable" do
    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path

    assert_response :success
    assert_includes response.body, "Your school day"
    assert_includes response.body, "Hour 1"
    assert_includes response.body, "09:00"
    assert_includes response.body, "Music theory"
    assert_includes response.body, "Music practice"
    assert_includes response.body, "Lunch"
    assert_includes response.body, "Comfort break"
    assert_includes response.body, "Day"
    assert_includes response.body, "Week"
  end

  test "child dashboard week view shows Monday to Friday" do
    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(view: "week")

    assert_response :success
    assert_includes response.body, "This week"
    assert_includes response.body, "Mon"
    assert_includes response.body, "Fri"
    assert_includes response.body, "09:00"
    assert_includes response.body, "Lunch"
    assert_includes response.body, "Break"
    assert_includes response.body, "Music practice"
  end

  test "week view draws the live now line during school hours" do
    travel_to Time.zone.local(2026, 9, 15, 10, 5, 0)
    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(view: "week")

    assert_response :success
    assert_includes response.body, "week-board-now-line"
    assert_includes response.body, "is-now"
  end

  test "opening a slot still shows the lesson" do
    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(lesson_id: @english.id)

    assert_response :success
    assert_includes response.body, @english.title
    assert_not_includes response.body, "Your school day"
  end

  test "practice lesson has no oak iframe and can be completed" do
    practice = Curriculum::MusicPracticeSeeder.ensure_for_year!("year_7")
    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(lesson_id: practice.id)

    assert_response :success
    assert_includes response.body, "Practise your instrument"
    assert_not_includes response.body, "oak-hub"
    assert_not_includes response.body, "Open on Oak"

    post lesson_completions_path, params: { lesson_id: practice.id }
    assert @child.reload.completed?(practice)
  end

  test "day view after the third week in July is summer holiday" do
    travel_to Date.new(2027, 7, 26)
    post user_session_path, params: {
      user: { email: @child.email, password: "Password123!" }
    }
    get child_dashboard_path(view: "day", date: "2027-07-26")

    assert_response :success
    assert_includes response.body, "Summer holiday"
    assert_not_includes response.body, "Hour 1"
  end
end
