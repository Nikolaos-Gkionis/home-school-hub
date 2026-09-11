# frozen_string_literal: true

require "test_helper"

class CurriculumSchoolWeekTest < ActiveSupport::TestCase
  setup do
    travel_to Date.new(2026, 9, 16) # Wednesday
    @parent = User.create!(
      email: "school-week-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @child = User.create!(
      email: "school-week-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7")
    @child.update!(active_learner: @child.learners.first)
  end

  test "builds Monday to Friday from the same week" do
    week = Curriculum::SchoolWeek.call(@child)

    assert_equal Date.new(2026, 9, 14), week.monday
    assert_equal Date.new(2026, 9, 18), week.friday
    assert_equal 5, week.days.size
    assert_equal %w[Mon Tue Wed Thu Fri], week.days.map(&:short_weekday)
    assert_equal 5, week.hour_rows.size
    assert_equal 9, week.timeline_rows.size
    assert_equal %w[p1 b1 p2 b2 p3 lunch p4 b3 p5], week.timeline_rows.map { |row| row[:key] }
  end

  test "next week is blocked after the third week in July" do
    last_week = Curriculum::SchoolWeek.call(@child, Date.new(2027, 7, 19))
    assert last_week.days.all?(&:in_term?)
    assert_not last_week.next_week_in_term?

    holiday_week = Curriculum::SchoolWeek.call(@child, Date.new(2027, 7, 26))
    assert holiday_week.days.none?(&:in_term?)
    assert holiday_week.previous_week_in_term?
  end
end
