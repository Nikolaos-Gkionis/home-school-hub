# frozen_string_literal: true

require "test_helper"

class CurriculumTimetableClockTest < ActiveSupport::TestCase
  test "five teaching hours sit around breaks and lunch" do
    keys = Curriculum::TimetableClock::PERIODS.map(&:key)
    assert_equal %w[p1 b1 p2 b2 p3 lunch p4 b3 p5], keys
    assert_equal 5, Curriculum::TimetableClock::TEACHING_PERIODS.size
  end

  test "current period is the 10:00 comfort break at 10:05" do
    travel_to Time.zone.local(2026, 9, 14, 10, 5, 0)

    assert_equal "b1", Curriculum::TimetableClock.current_period_key
    assert Curriculum::TimetableClock.now?(Date.new(2026, 9, 14), "b1")
    assert_not Curriculum::TimetableClock.now?(Date.new(2026, 9, 14), "p1")
  end

  test "now line is present during school hours and blank after 15:15" do
    travel_to Time.zone.local(2026, 9, 14, 12, 45, 0)
    assert_match(/top:/, Curriculum::TimetableClock.now_line_style)

    travel_to Time.zone.local(2026, 9, 14, 16, 0, 0)
    assert_nil Curriculum::TimetableClock.now_line_style
    assert_nil Curriculum::TimetableClock.current_period_key
  end
end
