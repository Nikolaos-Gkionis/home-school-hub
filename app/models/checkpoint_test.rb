# frozen_string_literal: true

class CheckpointTest < ApplicationRecord
  MIN_COMPLETED_LESSONS = 20
  QUESTION_MIN = 40
  QUESTION_MAX = 50
  TARGET_QUESTION_COUNT = 45

  belongs_to :parent, class_name: "User"
  belongs_to :child, class_name: "User"

  validates :subject, presence: true
  validates :completed_lessons_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :question_count, numericality: { only_integer: true, greater_than_or_equal_to: QUESTION_MIN, less_than_or_equal_to: QUESTION_MAX }

  scope :recent_first, -> { order(created_at: :desc) }

  def self.eligible_subjects_for(child)
    LessonCompletion.joins(:lesson)
                    .where(user: child)
                    .group("lessons.subject")
                    .having("COUNT(*) >= ?", MIN_COMPLETED_LESSONS)
                    .count
                    .keys
                    .sort
  end
end
