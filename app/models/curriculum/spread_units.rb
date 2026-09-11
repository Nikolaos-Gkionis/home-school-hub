# frozen_string_literal: true

module Curriculum
  # Puts each subject's Oak units onto consecutive school months.
  # Unit 1 → September, unit 2 → October, and so on. Extra units wrap
  # around (unit 12 shares September with unit 1). Music theory is included
  # so hour 4 has a unit every month; instrument practice stays off the plan.
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

      created = 0
      units_by_subject.each_value do |units|
        units.each_with_index do |row, index|
          next if assigned?([ row[:subject], row[:unit] ])

          @child.unit_month_plans.create!(
            year_group_key: @year_key,
            academic_year: @academic_year,
            month: AcademicYear::PLAN_MONTHS[index % AcademicYear::PLAN_MONTHS.size],
            subject: row[:subject],
            unit: row[:unit]
          )
          created += 1
        end
      end
      created
    end

    private

    def assigned
      @assigned ||= @child.unit_month_plans
        .where(year_group_key: @year_key, academic_year: @academic_year)
        .pluck(:subject, :unit)
        .to_set
    end

    def assigned?(pair)
      assigned.include?(pair)
    end

    def units_by_subject
      positions = Lesson.where(year_group_key: @year_key)
        .where.not(subject: Lesson::OAK_SUBJECT_NAME)
        .not_practice
        .group(:subject, :unit)
        .minimum(:unit_position)

      rows = positions.keys.filter_map do |subject, unit|
        next if Lesson.practice_unit?(unit)

        { subject: subject, unit: unit, position: positions[[ subject, unit ]] || 9999 }
      end

      rows.sort_by { |row| [ row[:subject], row[:position], row[:unit] ] }
        .group_by { |row| row[:subject] }
    end
  end
end
