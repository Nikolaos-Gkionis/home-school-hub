# frozen_string_literal: true

module Insights
  # Aggregates lesson completion, quiz, and time metrics for the insights dashboard.
  class Summary
    def self.call(viewer:, scope_user:)
      new(viewer:, scope_user:).to_h
    end

    def initialize(viewer:, scope_user:)
      @viewer = viewer
      @scope_user = scope_user
    end

    def to_h
      users = target_users
      user_ids = users.map(&:id)

      completions = LessonCompletion.where(user_id: user_ids)
      quizzes = LessonQuizResponse.where(user_id: user_ids)
      time_logs = LessonTimeLog.where(user_id: user_ids)

      total_done = completions.distinct.count(:lesson_id)
      quiz_total = quizzes.count
      quiz_correct = quizzes.where(correct: true).count
      seconds = time_logs.sum(:seconds)

      by_week = completions.map(&:completed_at).each_with_object(Hash.new(0)) do |t, h|
        key = t.in_time_zone.beginning_of_week.to_date.to_s
        h[key] += 1
      end
      by_subject = completions.joins(:lesson).group("lessons.subject").count

      {
        learner_count: users.size,
        lessons_completed: total_done,
        quiz_attempts: quiz_total,
        quiz_correct: quiz_correct,
        quiz_success_ratio: quiz_total.positive? ? (quiz_correct.to_f / quiz_total) : 0.0,
        time_minutes: (seconds / 60.0).round(1),
        completions_by_week: by_week,
        completions_by_subject: by_subject
      }
    end

    private

    def target_users
      if @scope_user
        return [ @scope_user ] if @scope_user.id == @viewer.id
        return [ @scope_user ] if @viewer.parent? && @scope_user.parent_id == @viewer.id

        return [ @viewer ]
      end
      return @viewer.children.order(:email).to_a if @viewer.parent?

      [ @viewer ]
    end
  end
end
