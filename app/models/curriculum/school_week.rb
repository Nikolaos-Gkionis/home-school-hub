# frozen_string_literal: true

module Curriculum
  # Monday–Friday wrapper around SchoolDay. Same lesson pool, one column per day.
  class SchoolWeek
    SCHOOL_DAYS = SchoolDay::SCHOOL_DAYS

    def self.call(user, date = Date.current)
      new(user: user, date: date)
    end

    def initialize(user:, date: Date.current)
      @user = user
      @date = date
    end

    def monday
      @monday ||= @date.beginning_of_week(:monday)
    end

    def friday
      monday + (SCHOOL_DAYS - 1)
    end

    def previous_monday
      monday - 7
    end

    def next_monday
      monday + 7
    end

    def previous_week_in_term?
      school_days_in_week?(previous_monday)
    end

    def next_week_in_term?
      school_days_in_week?(next_monday)
    end

    def label
      "#{monday.strftime('%-d %b')} – #{friday.strftime('%-d %b %Y')}"
    end

    def days
      @days ||= (0...SCHOOL_DAYS).map { |i| SchoolDay.call(@user, monday + i) }
    end

    def hour_rows
      return [] if days.empty?

      days.first.slots.map.with_index do |slot, index|
        {
          hour: slot.hour,
          label: slot.label,
          period: slot.period,
          cells: days.map { |day| day.slots[index] }
        }
      end
    end

    # Same as hour_rows, but with break and lunch rows in between.
    def timeline_rows
      return [] if days.empty?

      days.first.timeline.map.with_index do |slot, index|
        {
          hour: slot.hour,
          key: slot.key,
          kind: slot.kind,
          label: slot.label,
          period: slot.period,
          starts_at: slot.starts_at,
          ends_at: slot.ends_at,
          cells: days.map { |day| day.timeline[index] }
        }
      end
    end

    private

    def school_days_in_week?(week_monday)
      (0...SCHOOL_DAYS).any? { |i| AcademicYear.school_date?(week_monday + i) }
    end
  end
end
