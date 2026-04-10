# frozen_string_literal: true

module Oak
  # Fetches lesson summary, assets, quizzes, and transcript from the API and caches JSON on +Lesson+.
  # Each endpoint is fetched independently so one failure (e.g. timeout on assets) does not discard
  # successful responses from the others.
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

      summary = fetch_json("/lessons/#{slug}/summary", @lesson.summary_json)
      assets = fetch_json("/lessons/#{slug}/assets", @lesson.assets_json)
      quiz = fetch_json("/lessons/#{slug}/quiz", @lesson.quizzes_json)
      transcript = fetch_transcript_json(slug)

      now = Time.current
      @lesson.update_columns(
        summary_json: coerce_hash(summary),
        assets_json: coerce_hash(assets),
        quizzes_json: coerce_hash(quiz),
        transcript_json: coerce_hash(transcript),
        oak_synced_at: now,
        updated_at: now
      )
      @lesson.reload
      HydrationResult.new(lesson: @lesson, reason: nil)
    rescue ApiClient::Unauthorized
      HydrationResult.new(lesson: @lesson, reason: :unauthorized)
    rescue JSON::ParserError => e
      Rails.logger.warn("[Oak::LessonHydrator] JSON parse error: #{e.message}")
      HydrationResult.new(lesson: @lesson, reason: :bad_response)
    rescue ApiClient::Error => e
      Rails.logger.warn("[Oak::LessonHydrator] #{e.class}: #{e.message}")
      HydrationResult.new(lesson: @lesson, reason: :bad_response)
    end

    private

    def coerce_hash(val)
      val.is_a?(Hash) ? val : {}
    end

    def wrap_fallback(fallback)
      fallback.is_a?(Hash) ? fallback : {}
    end

    def fetch_json(path, fallback)
      data = @fetcher.call(path)
      return data if data.is_a?(Hash)

      wrap_fallback(fallback)
    rescue ApiClient::Unauthorized
      raise
    rescue StandardError => e
      Rails.logger.warn("[Oak::LessonHydrator] #{path}: #{e.class}: #{e.message}")
      wrap_fallback(fallback)
    end

    def fetch_transcript_json(slug)
      @fetcher.call("/lessons/#{slug}/transcript")
    rescue ApiClient::BadResponse => e
      raise unless e.http_code == 404

      {}
    rescue StandardError => e
      Rails.logger.warn("[Oak::LessonHydrator] transcript /lessons/#{slug}/transcript: #{e.class}: #{e.message}")
      wrap_fallback(@lesson.transcript_json)
    end
  end
end
