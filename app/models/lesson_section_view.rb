# frozen_string_literal: true

class LessonSectionView < ApplicationRecord
  belongs_to :user
  belongs_to :lesson

  validates :section_key, presence: true
end
