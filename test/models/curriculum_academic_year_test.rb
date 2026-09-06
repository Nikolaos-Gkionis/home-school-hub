# frozen_string_literal: true

require "test_helper"

class CurriculumAcademicYearTest < ActiveSupport::TestCase
  test "start year is the September year" do
    assert_equal 2026, Curriculum::AcademicYear.start_year(Date.new(2026, 9, 1))
    assert_equal 2026, Curriculum::AcademicYear.start_year(Date.new(2027, 7, 31))
    assert_equal 2025, Curriculum::AcademicYear.start_year(Date.new(2026, 8, 31))
  end

  test "August uses July as the current plan month" do
    assert_equal 7, Curriculum::AcademicYear.current_month(Date.new(2026, 8, 10))
    assert_equal 9, Curriculum::AcademicYear.current_month(Date.new(2026, 9, 10))
  end

  test "September unlocks only September" do
    unlocked = Curriculum::AcademicYear.unlocked_months(Date.new(2026, 9, 15))
    assert_equal [ 9 ], unlocked
    assert Curriculum::AcademicYear.month_unlocked?(9, Date.new(2026, 9, 15))
    assert_not Curriculum::AcademicYear.month_unlocked?(10, Date.new(2026, 9, 15))
  end

  test "January unlocks autumn plus January" do
    unlocked = Curriculum::AcademicYear.unlocked_months(Date.new(2027, 1, 12))
    assert_equal [ 9, 10, 11, 12, 1 ], unlocked
  end

  test "calendar year for a plan month follows the September start" do
    assert_equal 2026, Curriculum::AcademicYear.calendar_year_for(9, 2026)
    assert_equal 2027, Curriculum::AcademicYear.calendar_year_for(1, 2026)
  end

  test "September 2026 school weeks start on Monday the 7th" do
    mondays = Curriculum::AcademicYear.school_week_mondays(9, 2026)

    assert_equal Date.new(2026, 9, 7), mondays.first
    assert_equal Date.new(2026, 9, 28), mondays.last
    assert_equal 4, mondays.size
  end

  test "October 2026 school weeks start on the first Monday in October" do
    mondays = Curriculum::AcademicYear.school_week_mondays(10, 2026)

    assert_equal Date.new(2026, 10, 5), mondays.first
    assert_not_includes mondays, Date.new(2026, 9, 28)
  end
end
