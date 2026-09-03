# frozen_string_literal: true

module Curriculum
  # Drops leftover Oak units evenly into empty months (or every month if none are empty).
  class SpreadUnits
    def self.call(child:, academic_year: AcademicYear.start_year)
      new(child: child, academic_year: academic_year).call
    end

    def initialize(child:, academic_year:)
      @child = child
      @academic_year = academic_year
      @year_key = child.current_year_group_key
    end

    def call
      return 0 if @year_key.blank?

      remaining = remaining_units
      return 0 if remaining.empty?

      targets = empty_months.presence || AcademicYear::PLAN_MONTHS
      remaining.each_with_index do |row, index|
        @child.unit_month_plans.create!(
          year_group_key: @year_key,
          academic_year: @academic_year,
          month: targets[index % targets.size],
          subject: row[:subject],
          unit: row[:unit]
        )
      end
      remaining.size
    end

    private

    def remaining_units
      positions = Lesson.where(year_group_key: @year_key)
        .where.not(subject: Lesson::OAK_SUBJECT_NAME)
        .group(:subject, :unit)
        .minimum(:unit_position)

      assigned = @child.unit_month_plans
        .where(year_group_key: @year_key, academic_year: @academic_year)
        .pluck(:subject, :unit)
        .to_set

      positions.keys.filter_map do |subject, unit|
        next if assigned.include?([ subject, unit ])

        { subject: subject, unit: unit, position: positions[[ subject, unit ]] || 9999 }
      end.sort_by { |row| [ row[:subject], row[:position], row[:unit] ] }
    end

    def empty_months
      AcademicYear::PLAN_MONTHS.select do |month|
        @child.unit_month_plans.where(
          year_group_key: @year_key,
          academic_year: @academic_year,
          month: month
        ).none?
      end
    end
  end
end
