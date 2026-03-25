# frozen_string_literal: true

class LessonCompletion < ApplicationRecord
  belongs_to :user
  belongs_to :lesson

  validates :completed_at, presence: true
end
