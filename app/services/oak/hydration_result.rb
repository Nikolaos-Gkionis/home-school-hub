# frozen_string_literal: true

module Oak
  # Outcome of Oak::LessonHydrator so dashboards can show user-visible API errors.
  class HydrationResult
    attr_reader :lesson, :reason

    def initialize(lesson:, reason: nil)
      @lesson = lesson
      @reason = reason
    end

    def ok?
      reason.nil?
    end

    def failure?
      !ok?
    end

    def user_message
      return if ok?

      case reason
      when :unauthorized
        "Oak could not verify your API key. Check OAK_API_TOKEN (or OAK_API_AUTH_HEADER) on the server and restart the app."
      when :rate_limited
        "Oak’s API is rate-limiting requests right now. Try again in a minute."
      when :bad_response
        "We couldn’t load this lesson from Oak’s API. Try again later or open the lesson on Oak’s site."
      when :missing_slug
        nil
      else
        "We couldn’t refresh lesson content from Oak. Try again later."
      end
    end
  end
end
