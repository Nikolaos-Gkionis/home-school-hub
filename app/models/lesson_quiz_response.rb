# frozen_string_literal: true

class LessonQuizResponse < ApplicationRecord
  belongs_to :user
  belongs_to :lesson

  QUIZ_TYPES = %w[starter exit].freeze

  validates :quiz_type, presence: true, inclusion: { in: QUIZ_TYPES }
  validates :question_index, presence: true
end
