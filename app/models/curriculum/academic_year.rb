# frozen_string_literal: true

module Curriculum
  # UK teaching year: September → the Friday of the third week in July.
  # August (and the rest of July after that Friday) is holiday. Unlocking
  # still treats August as July so last month's units stay open.
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

    def self.first_school_date(academic_year = start_year)
      Date.new(academic_year.to_i, 9, 1)
    end

    # Friday of the third Monday-week in July. Week 1 is the week of the
    # first Monday in July, week 2 the next Monday, week 3 the one after.
    def self.last_school_date(academic_year = start_year)
      july = Date.new(calendar_year_for(7, academic_year), 7, 1)
      mondays = (july..july.end_of_month).select(&:monday?)
      mondays.fetch(2) + 4
    end

    def self.term_date?(date = Date.current)
      date = date.to_date
      year = start_year(date)
      date >= first_school_date(year) && date <= last_school_date(year)
    end

    # First Monday that actually sits in the plan month.
    # 1 September 2026 is a Tuesday, so the weekly calendar starts Monday the 7th.
    def self.first_school_monday(month, academic_year)
      start_date = month_start(month, academic_year)
      cursor = monday_of(start_date)
      date_in_month?(cursor, start_date) ? cursor : cursor + 7
    end

    # With month + year: a weekday in that plan month, on or after the first
    # Monday, still inside term (used by the weekly calendar).
    # With only a date: any weekday inside the September → July term
    # (used by Day/Week).
    def self.school_date?(date = Date.current, month = nil, academic_year = nil)
      date = date.to_date
      return date.wday.between?(1, 5) && term_date?(date) if month.nil?

      start_date = month_start(month, academic_year)
      return false unless date.wday.between?(1, 5)
      return false unless date_in_month?(date, start_date)
      return false unless date >= first_school_monday(month, academic_year)

      term_date?(date)
    end

    def self.school_dates_for_monday(monday, month, academic_year)
      (0..4).filter_map do |offset|
        date = monday.to_date + offset
        date if school_date?(date, month, academic_year)
      end
    end

    # Mondays of school weeks that start in this plan month.
    def self.school_week_mondays(month, academic_year)
      finish = month_start(month, academic_year).end_of_month
      mondays = []
      cursor = first_school_monday(month, academic_year)

      while cursor <= finish
        mondays << cursor if school_dates_for_monday(cursor, month, academic_year).any?
        cursor += 7
      end

      mondays
    end

    def self.date_in_month?(date, month_start)
      date.month == month_start.month && date.year == month_start.year
    end
  end
end
