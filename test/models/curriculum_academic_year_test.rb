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
end
