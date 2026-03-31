# frozen_string_literal: true

module Oak
  # Fetches lesson summary, assets, quizzes, and transcript from the API and caches JSON on +Lesson+.
  class LessonHydrator
    STALE_AFTER = 7.days

    class << self
      def call(lesson, fetcher: nil)
        new(lesson, fetcher: fetcher).call
      end

      def stale?(lesson)
        return true if lesson.oak_synced_at.blank?

        lesson.oak_synced_at < STALE_AFTER.ago
      end
    end

    def initialize(lesson, fetcher: nil)
      @lesson = lesson
      @fetcher = fetcher || ->(path) { ApiClient.get_json(path) }
    end

    def call
      return HydrationResult.new(lesson: @lesson, reason: :missing_slug) unless @lesson.oak_hub?
      return HydrationResult.new(lesson: @lesson, reason: nil) unless ApiClient.configured?

      slug = @lesson.oak_lesson_slug
      return HydrationResult.new(lesson: @lesson, reason: :missing_slug) if slug.blank?

      summary = @fetcher.call("/lessons/#{slug}/summary")
      assets = @fetcher.call("/lessons/#{slug}/assets")
      quiz = @fetcher.call("/lessons/#{slug}/quiz")
      transcript = fetch_transcript(slug)

      now = Time.current
      @lesson.update_columns(
        summary_json: summary,
        assets_json: assets,
        quizzes_json: quiz,
        transcript_json: transcript,
        oak_synced_at: now,
        updated_at: now
      )
      @lesson.reload
      HydrationResult.new(lesson: @lesson, reason: nil)
    rescue ApiClient::Unauthorized
      HydrationResult.new(lesson: @lesson, reason: :unauthorized)
    rescue ApiClient::RateLimited
      HydrationResult.new(lesson: @lesson, reason: :rate_limited)
    rescue JSON::ParserError => e
      Rails.logger.warn("[Oak::LessonHydrator] JSON parse error: #{e.message}")
      HydrationResult.new(lesson: @lesson, reason: :bad_response)
    rescue ApiClient::BadResponse => e
      Rails.logger.warn("[Oak::LessonHydrator] #{e.message}")
      HydrationResult.new(lesson: @lesson, reason: :bad_response)
    rescue ApiClient::Error => e
      Rails.logger.warn("[Oak::LessonHydrator] #{e.message}")
      HydrationResult.new(lesson: @lesson, reason: :bad_response)
    end

    private

    def fetch_transcript(slug)
      @fetcher.call("/lessons/#{slug}/transcript")
    rescue ApiClient::BadResponse => e
      raise unless e.http_code == 404

      {}
    end
  end
end
