# frozen_string_literal: true

module Curriculum
  # UK teaching year: September → July. August is holiday and uses July's unlocks.
  class AcademicYear
    PLAN_MONTHS = [ 9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7 ].freeze

    def self.start_year(date = Date.current)
      date.month >= 9 ? date.year : date.year - 1
    end

    def self.current_month(date = Date.current)
      date.month == 8 ? 7 : date.month
    end

    def self.label_for(month)
      Date::MONTHNAMES[month.to_i]
    end

    def self.short_label(month)
      Date::ABBR_MONTHNAMES[month.to_i]
    end

    def self.index_of(month)
      PLAN_MONTHS.index(month.to_i)
    end

    def self.plan_month?(month)
      PLAN_MONTHS.include?(month.to_i)
    end

    def self.unlocked_months(date = Date.current)
      idx = index_of(current_month(date))
      return [] if idx.nil?

      PLAN_MONTHS[0..idx]
    end

    def self.month_unlocked?(month, date = Date.current)
      unlocked_months(date).include?(month.to_i)
    end

    # January–July belong to the academic year that started last September.
    # Example: academic year 2026 + month 1 → 1 January 2027.
    def self.calendar_year_for(month, academic_year)
      month.to_i >= 9 ? academic_year.to_i : academic_year.to_i + 1
    end

    def self.month_start(month, academic_year)
      Date.new(calendar_year_for(month, academic_year), month.to_i, 1)
    end

    def self.monday_of(date)
      date.to_date.beginning_of_week(:monday)
    end

    # Mondays of school weeks that have at least one Mon–Fri day in this plan month.
    def self.school_week_mondays(month, academic_year)
      start_date = month_start(month, academic_year)
      finish = start_date.end_of_month
      mondays = []
      cursor = monday_of(start_date)

      while cursor <= finish
        mondays << cursor if (0..4).any? { |offset| date_in_month?(cursor + offset, start_date) }
        cursor += 7
      end

      mondays
    end

    def self.date_in_month?(date, month_start)
      date.month == month_start.month && date.year == month_start.year
    end
  end
end
