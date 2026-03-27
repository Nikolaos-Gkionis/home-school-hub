# frozen_string_literal: true

class LessonTimeLog < ApplicationRecord
  belongs_to :user
  belongs_to :lesson

  validates :seconds, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :logged_on, presence: true

  def self.append_seconds!(user:, lesson:, seconds:)
    return if seconds.to_i <= 0

    day = Time.zone.today
    log = find_or_initialize_by(user: user, lesson: lesson, logged_on: day)
    log.seconds = log.seconds.to_i + seconds.to_i
    log.save!
  end
end
