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
  end
end
