# frozen_string_literal: true

# One Oak unit assigned to one month of a child's academic year.
class UnitMonthPlan < ApplicationRecord
  belongs_to :user

  validates :year_group_key, presence: true, inclusion: { in: Curriculum::YearGroups.all_year_keys }
  validates :academic_year, presence: true, numericality: { only_integer: true }
  validates :month, inclusion: { in: Curriculum::AcademicYear::PLAN_MONTHS }
  validates :subject, :unit, presence: true
  validates :unit, uniqueness: { scope: [ :user_id, :year_group_key, :academic_year, :subject ] }

  def unit_key
    Lesson.compose_unit_key(subject, unit)
  end
end
