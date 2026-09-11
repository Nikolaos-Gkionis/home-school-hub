# frozen_string_literal: true

module Curriculum
  # Clock face for the school day. Lesson assignment still lives on SchoolDay;
  # this only answers "when does hour 3 start?" and "what is happening now?"
  #
  # 09:00–15:15, five hour-long lessons, 15-minute comfort breaks, 30-minute lunch.
  class TimetableClock
    Period = Struct.new(:key, :starts_at, :ends_at, :kind, :label, keyword_init: true) do
      def start_minutes
        clock_to_minutes(starts_at)
      end

      def end_minutes
        clock_to_minutes(ends_at)
      end

      def duration_minutes
        end_minutes - start_minutes
      end

      # Minutes after 09:00 — used to paint the block on the calendar.
      def offset_minutes
        start_minutes - DAY_START_MINUTES
      end

      def lesson?
        kind == :lesson
      end

      private

      def clock_to_minutes(value)
        hours, minutes = value.split(":").map(&:to_i)
        (hours * 60) + minutes
      end
    end

    DAY_START_MINUTES = 9 * 60
    DAY_END_MINUTES = (15 * 60) + 15
    DAY_MINUTES = DAY_END_MINUTES - DAY_START_MINUTES
    PIXELS_PER_MINUTE = 1.35
    # Matching empty strips above 09:00 and below 15:15 so the first
    # and last lesson blocks are not glued to the frame.
    GUTTER_TOP_PX = 28
    GUTTER_BOTTOM_PX = 28

    PERIODS = [
      Period.new(key: "p1", starts_at: "09:00", ends_at: "10:00", kind: :lesson, label: "Lesson"),
      Period.new(key: "b1", starts_at: "10:00", ends_at: "10:15", kind: :break, label: "Comfort break"),
      Period.new(key: "p2", starts_at: "10:15", ends_at: "11:15", kind: :lesson, label: "Lesson"),
      Period.new(key: "b2", starts_at: "11:15", ends_at: "11:30", kind: :break, label: "Comfort break"),
      Period.new(key: "p3", starts_at: "11:30", ends_at: "12:30", kind: :lesson, label: "Lesson"),
      Period.new(key: "lunch", starts_at: "12:30", ends_at: "13:00", kind: :lunch, label: "Lunch"),
      Period.new(key: "p4", starts_at: "13:00", ends_at: "14:00", kind: :lesson, label: "Lesson"),
      Period.new(key: "b3", starts_at: "14:00", ends_at: "14:15", kind: :break, label: "Comfort break"),
      Period.new(key: "p5", starts_at: "14:15", ends_at: "15:15", kind: :lesson, label: "Lesson")
    ].freeze

    TEACHING_PERIODS = PERIODS.select(&:lesson?).freeze
    HOUR_MARKS = %w[09:00 10:00 11:00 12:00 13:00 14:00 15:00 15:15].freeze

    def self.teaching_index(key)
      TEACHING_PERIODS.index { |period| period.key == key.to_s }
    end

    def self.period_for(key)
      PERIODS.find { |period| period.key == key.to_s }
    end

    def self.current_period_key(time = Time.current)
      minutes = (time.hour * 60) + time.min
      PERIODS.each do |period|
        return period.key if minutes >= period.start_minutes && minutes < period.end_minutes
      end
      nil
    end

    def self.now?(date, period_key, time = Time.current)
      date == time.to_date && period_key.to_s == current_period_key(time)
    end

    def self.clock_top(offset_minutes)
      GUTTER_TOP_PX + (offset_minutes * PIXELS_PER_MINUTE)
    end

    def self.block_style(period)
      top = clock_top(period.offset_minutes)
      height = period.duration_minutes * PIXELS_PER_MINUTE
      "top: #{top}px; height: #{height}px;"
    end

    def self.day_height_style
      "height: #{GUTTER_TOP_PX + (DAY_MINUTES * PIXELS_PER_MINUTE) + GUTTER_BOTTOM_PX}px;"
    end

    def self.hour_mark_style(time)
      hours, minutes = time.split(":").map(&:to_i)
      top = clock_top((hours * 60) + minutes - DAY_START_MINUTES)
      "top: #{top}px;"
    end

    # Pixel offset for the red "now" line. Nil when we are outside 09:00–15:15.
    def self.now_line_style(time = Time.current)
      minutes = (time.hour * 60) + time.min
      return nil if minutes < DAY_START_MINUTES || minutes > DAY_END_MINUTES

      "top: #{clock_top(minutes - DAY_START_MINUTES)}px;"
    end
  end
end
