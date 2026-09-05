# frozen_string_literal: true

require "test_helper"

class Curriculum::WeekCalendarTest < ActiveSupport::TestCase
  setup do
    travel_to Time.zone.local(2026, 9, 15, 10, 30)
    @parent = User.create!(
      email: "week-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @child = User.create!(
      email: "week-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7")
    @child.update!(active_learner: @child.learners.first)
  end

  test "empty plan returns no units" do
    result = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026)

    assert_not result.has_units
    assert_equal "September", result.month_label
    assert result.weeks.any?
  end

  test "school day is 9:00 to 15:15 with lunch in the middle" do
    seed_month_units
    result = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026, week_monday: Date.new(2026, 9, 14))
    monday = result.selected_week.dates.first
    keys = result.selected_week.slots.select { |slot| slot.date == monday }.map { |slot| slot.period.key }

    assert_equal %w[p1 b1 p2 b2 p3 lunch p4 b3 p5], keys
    assert_equal "09:00", Curriculum::WeekCalendar::PERIODS.first.starts_at
    assert_equal "15:15", Curriculum::WeekCalendar::PERIODS.last.ends_at
    assert_equal 60, Curriculum::WeekCalendar.period_for("p5").duration_minutes
    assert_equal 15, Curriculum::WeekCalendar.period_for("b1").duration_minutes
    assert_equal 15, Curriculum::WeekCalendar.period_for("b3").duration_minutes
    assert_equal 30, Curriculum::WeekCalendar.period_for("lunch").duration_minutes
  end

  test "English and Maths doubles sit back to back on the same day" do
    seed_month_units
    result = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026, week_monday: Date.new(2026, 9, 14))
    week = result.selected_week
    doubled = 0

    week.dates.each do |date|
      taught = Curriculum::WeekCalendar::TEACHING_PERIODS.map do |period|
        week.slots.find { |slot| slot.date == date && slot.period.key == period.key }
      end

      %w[English Mathematics].each do |subject|
        keys = taught.select { |slot| slot.lesson&.subject == subject }.map { |slot| slot.period.key }
        next if keys.size < 2

        doubled += 1
        assert Curriculum::WeekCalendar.back_to_back?(keys),
          "#{subject} on #{date} should be next to each other, got #{keys}"
        assert_not keys.include?("p3") && keys.include?("p4") && keys.size == 2,
          "#{subject} on #{date} should not sit across lunch"
      end
    end

    assert doubled.positive?, "expected at least one English or Maths double in #{week.subject_counts.inspect}"
  end

  test "core subjects get more lessons than foundation subjects" do
    seed_month_units
    result = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026, week_monday: Date.new(2026, 9, 14))
    counts = result.selected_week.subject_counts

    assert counts["English"] > counts["History"], "English should beat History: #{counts.inspect}"
    assert counts["Mathematics"] > counts["History"], "Maths should beat History: #{counts.inspect}"
    assert counts["Science"] > counts["History"], "Science should beat History: #{counts.inspect}"
    assert counts["History"].positive?
    assert counts["Art and design"].positive?
  end

  test "lessons come from the monthly unit plan" do
    seed_month_units
    result = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026)
    titles = result.weeks.flat_map { |week| week.slots.filter_map { |slot| slot.lesson&.title } }

    assert titles.any? { |title| title.start_with?("English") }
    assert_not titles.any? { |title| title.start_with?("October") }
  end

  test "the same plan always builds the same week" do
    seed_month_units
    first = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026, week_monday: Date.new(2026, 9, 14))
    second = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026, week_monday: Date.new(2026, 9, 14))

    assert_equal lesson_ids(first), lesson_ids(second)
  end

  test "completed lessons are marked on the grid" do
    seed_month_units
    lesson = Lesson.find_by!(subject: "English", title: "English 1")
    @child.lesson_completions.create!(lesson: lesson, completed_at: Time.current)

    result = Curriculum::WeekCalendar.call(
      child: @child,
      month: 9,
      academic_year: 2026,
      completed_lesson_ids: @child.lesson_completions.pluck(:lesson_id)
    )
    slot = result.weeks.flat_map(&:slots).find { |item| item.lesson&.id == lesson.id }

    assert slot.completed
  end

  test "current period key follows the 9:00 to 15:15 clock" do
    assert_equal "p2", Curriculum::WeekCalendar.current_period_key(Time.zone.local(2026, 9, 15, 10, 30))
    assert_equal "b1", Curriculum::WeekCalendar.current_period_key(Time.zone.local(2026, 9, 15, 10, 5))
    assert_equal "lunch", Curriculum::WeekCalendar.current_period_key(Time.zone.local(2026, 9, 15, 12, 40))
    assert_equal "b3", Curriculum::WeekCalendar.current_period_key(Time.zone.local(2026, 9, 15, 14, 5))
    assert_equal "p5", Curriculum::WeekCalendar.current_period_key(Time.zone.local(2026, 9, 15, 15, 10))
    assert_nil Curriculum::WeekCalendar.current_period_key(Time.zone.local(2026, 9, 15, 16, 0))
  end

  test "now line sits on the 9:00 to 15:15 clock and hides after school" do
    style = Curriculum::WeekCalendar.now_line_style(Time.zone.local(2026, 9, 15, 10, 30))
    assert_includes style, "top:"
    assert_nil Curriculum::WeekCalendar.now_line_style(Time.zone.local(2026, 9, 15, 16, 0))
    assert_nil Curriculum::WeekCalendar.now_line_style(Time.zone.local(2026, 9, 15, 8, 0))
  end

  test "dragging two slots swaps the lessons and remembers them" do
    seed_month_units
    result = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026, week_monday: Date.new(2026, 9, 14))
    monday = result.selected_week.dates.first
    first = result.selected_week.slots.find { |slot| slot.date == monday && slot.period.key == "p1" }
    second = result.selected_week.slots.find { |slot| slot.date == monday && slot.period.key == "p2" }
    assert first.lesson
    assert second.lesson

    Curriculum::WeekCalendar.swap!(
      child: @child,
      from_date: monday,
      from_period: "p1",
      to_date: monday,
      to_period: "p2",
      month: 9,
      week_monday: Date.new(2026, 9, 14)
    )

    moved = Curriculum::WeekCalendar.call(child: @child, month: 9, academic_year: 2026, week_monday: Date.new(2026, 9, 14))
    assert moved.customized
    assert_equal second.lesson.id, moved.slot_at(monday, Curriculum::WeekCalendar.period_for("p1")).lesson.id
    assert_equal first.lesson.id, moved.slot_at(monday, Curriculum::WeekCalendar.period_for("p2")).lesson.id
  end

  private

  def seed_month_units
    {
      "English" => "Stories",
      "Mathematics" => "Place value",
      "Science" => "Cells",
      "History" => "Romans",
      "Art and design" => "Colour"
    }.each do |subject, unit|
      8.times { |index| create_lesson(subject: subject, unit: unit, position: index + 1) }
      @child.unit_month_plans.create!(
        year_group_key: "year_7",
        academic_year: 2026,
        month: 9,
        subject: subject,
        unit: unit
      )
    end

    create_lesson(subject: "English", unit: "Later stories", position: 1, title: "October English 1")
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 10,
      subject: "English",
      unit: "Later stories"
    )
  end

  def create_lesson(subject:, unit:, position:, title: nil)
    slug = "#{subject}-#{unit}-#{position}".parameterize
    Lesson.create!(
      year_group_key: "year_7",
      subject: subject,
      unit: unit,
      unit_position: 1,
      title: title || "#{subject} #{position}",
      external_url: "https://www.thenational.academy/pupils/lessons/#{slug}",
      oak_lesson_slug: slug,
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: position
    )
  end

  def lesson_ids(result)
    result.selected_week.slots.map { |slot| slot.lesson&.id }
  end
end
