# frozen_string_literal: true

module Insights
  # Aggregates lesson completion, quiz, time, and section-view metrics for the insights dashboard.
  # All figures are read from the database scoped by +User+ ids (signed-in accounts), not transient session data.
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
      section_views = LessonSectionView.where(user_id: user_ids)

      total_done = completions.distinct.count(:lesson_id)
      quiz_total = quizzes.count
      quiz_correct = quizzes.where(correct: true).count
      seconds = time_logs.sum(:seconds)
      sections_explored = section_views.count

      by_week = completions.map(&:completed_at).each_with_object(Hash.new(0)) do |t, h|
        key = t.in_time_zone.beginning_of_week.to_date.to_s
        h[key] += 1
      end
      by_subject = completions.joins(:lesson).group("lessons.subject").count

      per_learner = users.map { |u| learner_row(u) }
      daily_lessons = daily_lesson_breakdown(users)
      daily_time = daily_time_breakdown(users)

      {
        learner_count: users.size,
        lessons_completed: total_done,
        quiz_attempts: quiz_total,
        quiz_correct: quiz_correct,
        quiz_success_ratio: quiz_total.positive? ? (quiz_correct.to_f / quiz_total) : 0.0,
        time_minutes: (seconds / 60.0).round(1),
        sections_explored: sections_explored,
        completions_by_week: by_week,
        completions_by_subject: by_subject,
        per_learner: per_learner,
        daily_lesson_dates: daily_lessons[:dates],
        daily_lesson_rows: daily_lessons[:rows],
        daily_lesson_totals: daily_lessons[:totals],
        daily_time_dates: daily_time[:dates],
        daily_time_rows: daily_time[:rows],
        daily_time_totals: daily_time[:totals]
      }
    end

    private

    def learner_row(user)
      uid = user.id
      comp = LessonCompletion.where(user_id: uid)
      quizzes = LessonQuizResponse.where(user_id: uid)
      time_logs = LessonTimeLog.where(user_id: uid)
      sections = LessonSectionView.where(user_id: uid)
      qn = quizzes.count
      qc = quizzes.where(correct: true).count

      {
        user_id: user.id,
        label: user.email,
        lessons_completed: comp.distinct.count(:lesson_id),
        quiz_attempts: qn,
        quiz_correct: qc,
        quiz_success_ratio: qn.positive? ? (qc.to_f / qn) : 0.0,
        time_minutes: (time_logs.sum(:seconds) / 60.0).round(1),
        sections_explored: sections.count
      }
    end

    def target_users
      if @scope_user
        return [ @scope_user ] if @scope_user.id == @viewer.id
        return [ @scope_user ] if @viewer.parent? && @scope_user.parent_id == @viewer.id

        return [ @viewer ]
      end
      # Progress is stored per signed-in user. Learner profiles (year/subject) belong to
      # the parent account; families without invited child logins record all activity on
      # the parent user, while child user accounts are separate invited logins only.
      if @viewer.parent?
        child_users = @viewer.children.order(:email).to_a
        return child_users if child_users.any?

        return [ @viewer ]
      end

      [ @viewer ]
    end

    def daily_lesson_breakdown(users)
      user_ids = users.map(&:id)
      grouped = LessonCompletion.where(user_id: user_ids)
                               .group(:user_id)
                               .group("DATE(completed_at)")
                               .count

      all_dates = grouped.keys.map { |(_, date)| date.to_s }.uniq.sort.last(14)
      rows = users.map do |user|
        by_date = all_dates.index_with do |date|
          grouped.fetch([ user.id, date ], 0)
        end

        {
          user_id: user.id,
          label: user.email,
          by_date: by_date,
          total: by_date.values.sum
        }
      end

      totals = all_dates.index_with { |date| rows.sum { |row| row[:by_date][date].to_i } }

      { dates: all_dates, rows: rows, totals: totals }
    end

    def daily_time_breakdown(users)
      user_ids = users.map(&:id)
      grouped = LessonTimeLog.where(user_id: user_ids)
                             .group(:user_id)
                             .group(:logged_on)
                             .sum(:seconds)
      grouped_by_string_date = grouped.each_with_object({}) do |((uid, date), seconds), acc|
        acc[[ uid, date.to_s ]] = seconds
      end

      all_dates = grouped.keys.map { |(_, date)| date.to_s }.uniq.sort.last(14)
      rows = users.map do |user|
        by_date = all_dates.index_with do |date|
          (grouped_by_string_date.fetch([ user.id, date ], 0).to_f / 60.0).round(1)
        end

        {
          user_id: user.id,
          label: user.email,
          by_date: by_date,
          total: by_date.values.sum.round(1)
        }
      end

      totals = all_dates.index_with do |date|
        rows.sum { |row| row[:by_date][date].to_f }.round(1)
      end

      { dates: all_dates, rows: rows, totals: totals }
    end
  end
end
