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
      grouped = Hash.new(0)
      LessonCompletion.where(user_id: user_ids).pluck(:user_id, :completed_at).each do |user_id, completed_at|
        grouped[[ user_id, calendar_date(completed_at) ]] += 1
      end

      build_daily_rows(users, grouped, integer_totals: true) { |count| count.to_i }
    end

    def daily_time_breakdown(users)
      user_ids = users.map(&:id)
      grouped = Hash.new(0)
      LessonTimeLog.where(user_id: user_ids).pluck(:user_id, :logged_on, :seconds).each do |user_id, logged_on, seconds|
        grouped[[ user_id, calendar_date(logged_on) ]] += seconds.to_i
      end

      result = build_daily_rows(users, grouped) { |seconds| (seconds.to_f / 60.0).round(1) }
      result[:rows].each { |row| row[:total] = row[:total].round(1) }
      result[:totals] = result[:totals].transform_values { |total| total.round(1) }
      result
    end

    # One column per calendar day, no matter how many logins/sessions that day.
    def build_daily_rows(users, grouped, integer_totals: false)
      all_dates = grouped.keys.map { |(_, date)| date }.uniq.sort
      rows = users.map do |user|
        by_date = all_dates.index_with do |date|
          yield grouped[[ user.id, date ]]
        end

        {
          user_id: user.id,
          label: user.email,
          by_date: by_date,
          total: by_date.values.sum
        }
      end

      totals = all_dates.index_with do |date|
        sum = rows.sum { |row| row[:by_date][date].to_f }
        integer_totals ? sum.to_i : sum
      end

      { dates: all_dates, rows: rows, totals: totals }
    end

    def calendar_date(value)
      case value
      when Date
        value.to_s
      when Time, DateTime
        value.in_time_zone.to_date.to_s
      else
        value.to_time.in_time_zone.to_date.to_s
      end
    end
  end
end
