# frozen_string_literal: true

require "test_helper"

module Oak
  class LessonHydratorTest < ActiveSupport::TestCase
    setup do
      @token_was = ENV.fetch("OAK_API_TOKEN", nil)
      ENV["OAK_API_TOKEN"] = "test-token"
    end

    teardown do
      ENV["OAK_API_TOKEN"] = @token_was
    end

    test "hydrates summary, transcript, and sets oak_synced_at via fetcher" do
      lesson = Lesson.create!(
        year_group_key: "year_7",
        subject: "Science",
        unit: "Forces",
        title: "Gravity",
        external_url: "https://www.thenational.academy/pupils/lessons/gravity-intro",
        oak_lesson_slug: "gravity-intro",
        content_mode: Lesson::CONTENT_MODE_OAK_HUB
      )

      fetcher = lambda do |path|
        case path
        when "/lessons/gravity-intro/summary"
          { "lessonTitle" => "Gravity intro", "pupilLessonOutcome" => "I can describe gravity." }
        when "/lessons/gravity-intro/assets"
          { "assets" => [ { "type" => "video", "label" => "Video", "url" => "https://example.test/v" } ], "attribution" => [ "Credit: Example" ] }
        when "/lessons/gravity-intro/quiz"
          { "starterQuiz" => [], "exitQuiz" => [] }
        when "/lessons/gravity-intro/transcript"
          { "transcript" => "Welcome to the lesson." }
        else
          {}
        end
      end

      result = LessonHydrator.new(lesson, fetcher: fetcher).call
      assert result.ok?
      lesson.reload
      assert_equal "Gravity intro", lesson.summary_json["lessonTitle"]
      assert_equal "Welcome to the lesson.", lesson.transcript_json["transcript"]
      assert lesson.oak_synced_at.present?
    end

    test "treats transcript 404 as empty hash" do
      lesson = Lesson.create!(
        year_group_key: "year_7",
        subject: "Science",
        unit: "Forces",
        title: "Gravity",
        external_url: "https://www.thenational.academy/pupils/lessons/no-transcript",
        oak_lesson_slug: "no-transcript",
        content_mode: Lesson::CONTENT_MODE_OAK_HUB
      )

      fetcher = lambda do |path|
        case path
        when "/lessons/no-transcript/summary"
          { "lessonTitle" => "No transcript lesson" }
        when "/lessons/no-transcript/assets"
          { "assets" => [] }
        when "/lessons/no-transcript/quiz"
          {}
        when "/lessons/no-transcript/transcript"
          raise ApiClient::BadResponse.new("not found", http_code: 404)
        else
          {}
        end
      end

      result = LessonHydrator.new(lesson, fetcher: fetcher).call
      assert result.ok?
      lesson.reload
      assert_equal({}, lesson.transcript_json)
    end

    test "still saves summary when another endpoint fails" do
      lesson = Lesson.create!(
        year_group_key: "year_7",
        subject: "Science",
        unit: "Forces",
        title: "Gravity",
        external_url: "https://www.thenational.academy/pupils/lessons/partial-lesson",
        oak_lesson_slug: "partial-lesson",
        content_mode: Lesson::CONTENT_MODE_OAK_HUB,
        summary_json: {},
        assets_json: { "assets" => [ { "type" => "video" } ] },
        quizzes_json: {},
        transcript_json: {}
      )

      fetcher = lambda do |path|
        case path
        when "/lessons/partial-lesson/summary"
          { "lessonTitle" => "Recovered title", "pupilLessonOutcome" => "Learn stuff." }
        when "/lessons/partial-lesson/assets", "/lessons/partial-lesson/quiz"
          raise ApiClient::BadResponse.new("server error", http_code: 500)
        when "/lessons/partial-lesson/transcript"
          { "transcript" => "Hi." }
        else
          {}
        end
      end

      result = LessonHydrator.new(lesson, fetcher: fetcher).call
      assert result.ok?
      lesson.reload
      assert_equal "Recovered title", lesson.summary_json["lessonTitle"]
      assert_equal "Hi.", lesson.transcript_json["transcript"]
      assert lesson.assets_json.is_a?(Hash) # kept previous assets when fetch failed
      assert lesson.assets_json["assets"].present?
    end

    test "reports rate_limited when Oak returns 429" do
      lesson = Lesson.create!(
        year_group_key: "year_8",
        subject: "Science",
        unit: "Forces",
        title: "Gravity",
        external_url: "https://www.thenational.academy/pupils/lessons/rate-limited-lesson",
        oak_lesson_slug: "rate-limited-lesson",
        content_mode: Lesson::CONTENT_MODE_OAK_HUB
      )

      fetcher = ->(_path) { raise ApiClient::RateLimited.new("slow down") }
      result = LessonHydrator.new(lesson, fetcher: fetcher).call
      assert_equal :rate_limited, result.reason
    end
  end
end
