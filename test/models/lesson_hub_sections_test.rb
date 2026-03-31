# frozen_string_literal: true

require "test_helper"

class LessonHubSectionsTest < ActiveSupport::TestCase
  test "hub_section_keys_for_lesson reflects available content" do
    lesson = Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: "Sentences",
      title: "Joining sentences",
      external_url: "https://www.thenational.academy/pupils/lessons/joining-using-and",
      oak_lesson_slug: "joining-using-and",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      summary_json: {
        "pupilLessonOutcome" => "I can join sentences.",
        "lessonKeywords" => [ { "keyword" => "and", "description" => "joining word" } ],
        "keyLearningPoints" => [ { "keyLearningPoint" => "And joins ideas." } ],
        "misconceptionsAndCommonMistakes" => [],
        "teacherTips" => [],
        "contentGuidance" => nil,
        "supervisionLevel" => nil
      },
      assets_json: { "assets" => [ { "type" => "video", "url" => "https://open-api.thenational.academy/api/v0/lessons/x/assets/video" } ] },
      quizzes_json: { "starterQuiz" => [ { "questionType" => "multiple-choice", "question" => "Q?", "answers" => [] } ] },
      transcript_json: { "transcript" => "Hello" }
    )

    keys = lesson.hub_section_keys_for_lesson
    assert_includes keys, "overview"
    assert_includes keys, "keywords"
    assert_includes keys, "video"
    assert_includes keys, "outcome"
    assert_includes keys, "starter_quiz"
    assert_includes keys, "transcript"
    assert_not_includes keys, "misconceptions"
  end

  test "downloadable_asset_rows excludes video" do
    lesson = Lesson.new(
      assets_json: {
        "assets" => [
          { "type" => "video", "url" => "https://example.test/v" },
          { "type" => "worksheet", "url" => "https://example.test/w" }
        ]
      }
    )
    types = lesson.downloadable_asset_rows.map { |a| a["type"] }
    assert_equal [ "worksheet" ], types
  end
end
