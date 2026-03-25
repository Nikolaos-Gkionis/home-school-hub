# frozen_string_literal: true

class Learner < ApplicationRecord
  belongs_to :user

  validates :year_group_key, presence: true, inclusion: { in: Curriculum::YearGroups.all_year_keys }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :assign_position, on: :create

  def display_name
    display_label.presence || Curriculum::YearGroups.label_for_year(year_group_key)
  end

  private

  def assign_position
    return if position.present?

    max = user.learners.where.not(id: id).maximum(:position)
    self.position = max.to_i + 1
  end
end
