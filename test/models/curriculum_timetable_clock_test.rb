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

  test "September school hours follow BST, not UTC" do
    # 09:05 UTC is 10:05 BST on 14 September 2026 — comfort break, not Hour 1.
    travel_to Time.utc(2026, 9, 14, 9, 5, 0)

    assert_equal "London", Time.zone.name
    assert_equal 10, Time.current.hour
    assert_equal "b1", Curriculum::TimetableClock.current_period_key
  end

  test "after the late-October clock change, school hours follow GMT" do
    # Last Sunday in October 2026 is the 25th. Monday 26th is GMT.
    # 10:05 UTC is 10:05 UK time — comfort break again.
    travel_to Time.utc(2026, 10, 26, 10, 5, 0)

    assert_equal 10, Time.current.hour
    assert_equal "b1", Curriculum::TimetableClock.current_period_key
  end
end
