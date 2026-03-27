# frozen_string_literal: true

module Gamification
  class StreakCalculator
    def self.call(user)
      new(user).weeks
    end

    def initialize(user)
      @user = user
    end

    def weeks
      dates = @user.lesson_completions.distinct.pluck(:completed_at).map { |t| t.to_date }.uniq.sort
      return 0 if dates.empty?

      streak = 1
      max_streak = 1
      (1...dates.size).each do |i|
        if (dates[i] - dates[i - 1]).to_i <= 7
          streak += 1
          max_streak = [ max_streak, streak ].max
        else
          streak = 1
        end
      end
      max_streak
    end
  end
end
