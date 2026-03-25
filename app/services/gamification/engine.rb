# frozen_string_literal: true

module Gamification
  class Engine
    def self.after_lesson_complete(user, lesson)
      new(user, lesson).evaluate
    end

    def initialize(user, lesson)
      @user = user
      @lesson = lesson
    end

    def evaluate
      check_subject_master
      check_daily_hero
    end

    private

    def check_subject_master
      s = @lesson.subject
      u = @lesson.unit
      yk = @lesson.year_group_key
      total = Lesson.where(subject: s, unit: u, year_group_key: yk).count
      return if total.zero?

      done = @user.lesson_completions
        .joins(:lesson)
        .where(lessons: { subject: s, unit: u, year_group_key: yk })
        .distinct
        .count(:lesson_id)
      return unless done >= total

      badge = Badge.find_by(key: "subject_master")
      return unless badge

      scope_key = "#{yk}:#{s}:#{u}"
      UserBadge.find_or_create_by!(user: @user, badge: badge, scope_key: scope_key) do |ub|
        ub.awarded_at = Time.current
        ub.metadata = { "year_group_key" => yk, "subject" => s, "unit" => u }
      end
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def check_daily_hero
      count = @user.lesson_completions.where(completed_at: 24.hours.ago..Time.current).distinct.count(:lesson_id)
      return if count < 3

      badge = Badge.find_by(key: "daily_hero")
      return unless badge

      scope_key = "day:#{Time.current.utc.to_date}"
      UserBadge.find_or_create_by!(user: @user, badge: badge, scope_key: scope_key) do |ub|
        ub.awarded_at = Time.current
      end
    rescue ActiveRecord::RecordNotUnique
      nil
    end
  end
end
