# frozen_string_literal: true

module Oak
  # Fetches lesson summary, assets, and quizzes from the API and caches JSON on +Lesson+.
  class LessonHydrator
    class << self
      def call(lesson)
        new(lesson).call
      end
    end

    def initialize(lesson)
      @lesson = lesson
    end

    def call
      return unless @lesson.oak_hub?
      return unless ApiClient.configured?

      slug = @lesson.oak_lesson_slug
      return if slug.blank?

      summary = ApiClient.get_json("/lessons/#{slug}/summary")
      assets = ApiClient.get_json("/lessons/#{slug}/assets")
      quiz = ApiClient.get_json("/lessons/#{slug}/quiz")

      @lesson.update_columns(
        summary_json: summary,
        assets_json: assets,
        quizzes_json: quiz,
        updated_at: Time.current
      )
      @lesson.reload
    rescue ApiClient::Error => e
      Rails.logger.warn("[Oak::LessonHydrator] #{e.message}")
    end
  end
end
