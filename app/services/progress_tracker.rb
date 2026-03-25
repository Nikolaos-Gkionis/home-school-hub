# frozen_string_literal: true

class ProgressTracker
  def self.mark_complete(user:, lesson:)
    return user.lesson_completions.find_by(lesson: lesson) if user.completed?(lesson)

    completion = nil
    ActiveRecord::Base.transaction do
      completion = user.lesson_completions.create!(lesson: lesson, completed_at: Time.current)
      Gamification::Engine.after_lesson_complete(user, lesson)
      user.update!(last_completed_lesson: lesson, last_active_lesson: lesson)
    end
    completion
  end
end
