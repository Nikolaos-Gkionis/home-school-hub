# frozen_string_literal: true

module Oak
  # Hydrates lessons that have missing summary after an import (bounded work + sleep throttle).
  class PostImportHydrator
    class << self
      def call(limit: nil, sleep_s: nil)
        limit ||= ENV.fetch("OAK_POST_IMPORT_HYDRATE_MAX", "80").to_i
        sleep_s = sleep_s.nil? ? ENV.fetch("OAK_POST_IMPORT_HYDRATE_SLEEP", "0.12").to_f : sleep_s

        return { hydrated: 0, skipped: true } unless ApiClient.configured?
        return { hydrated: 0, skipped: false } if limit <= 0

        hydrated = 0
        Lesson.where(content_mode: Lesson::CONTENT_MODE_OAK_HUB).where.not(oak_lesson_slug: nil).order(:id).find_each do |lesson|
          break if hydrated >= limit

          next if lesson.summary_json.is_a?(Hash) && lesson.summary_json["lessonTitle"].present?

          LessonHydrator.call(lesson)
          hydrated += 1
          sleep(sleep_s) if sleep_s.positive?
        end

        { hydrated:, skipped: false }
      end
    end
  end
end
