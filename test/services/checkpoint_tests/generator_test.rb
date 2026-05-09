# frozen_string_literal: true

require "test_helper"

class CheckpointTestsGeneratorTest < ActiveSupport::TestCase
  def test_builds_a_40_to_50_question_test_with_mixed_question_types
    parent = create_parent(email: "parent-generator@example.com")
    child = create_child(parent:, email: "child-generator@example.com")
    subject = "Mathematics"

    20.times do |idx|
      lesson = Lesson.create!(
        title: "Lesson #{idx + 1}",
        external_url: "https://example.com/lessons/#{idx + 1}",
        subject: subject,
        unit: "Unit #{(idx / 5) + 1}",
        year_group_key: child.learners.first.year_group_key,
        quizzes_json: quiz_payload(idx),
        summary_json: summary_payload(idx)
      )
      LessonCompletion.create!(user: child, lesson:, completed_at: Time.current - idx.hours)
    end

    checkpoint_test = CheckpointTests::Generator.call(parent:, child:, subject:)

    assert checkpoint_test.persisted?
    assert_equal subject, checkpoint_test.subject
    assert_operator checkpoint_test.question_count, :>=, 40
    assert_operator checkpoint_test.question_count, :<=, 50

    types = Array(checkpoint_test.questions_json).map { |q| q["type"] }.uniq
    assert_includes types, "multiple_choice"
    assert_includes types, "free_text"

    questions = Array(checkpoint_test.questions_json)
    mc_count = questions.count { |q| q["type"] == "multiple_choice" }
    required_mc = (questions.size * 0.7).floor
    assert_operator mc_count, :>=, required_mc
  end

  def test_falls_back_to_keyword_based_multiple_choice_when_quiz_payload_has_no_mc
    parent = create_parent(email: "parent-generator-fallback@example.com")
    child = create_child(parent:, email: "child-generator-fallback@example.com")
    subject = "Mathematics"

    20.times do |idx|
      lesson = Lesson.create!(
        title: "Fallback lesson #{idx + 1}",
        external_url: "https://example.com/fallback/#{idx + 1}",
        subject: subject,
        unit: "Unit #{(idx / 5) + 1}",
        year_group_key: child.learners.first.year_group_key,
        quizzes_json: { "starterQuiz" => [], "exitQuiz" => [] },
        summary_json: summary_payload(idx)
      )
      LessonCompletion.create!(user: child, lesson:, completed_at: Time.current - idx.hours)
    end

    checkpoint_test = CheckpointTests::Generator.call(parent:, child:, subject:)
    questions = Array(checkpoint_test.questions_json)
    mc_count = questions.count { |q| q["type"] == "multiple_choice" }
    required_mc = (questions.size * 0.7).floor

    assert_operator questions.size, :>=, 40
    assert_operator mc_count, :>=, required_mc
  end

  def test_rejects_visually_empty_quiz_options_and_uses_meaningful_mc_content
    parent = create_parent(email: "parent-generator-empty-options@example.com")
    child = create_child(parent:, email: "child-generator-empty-options@example.com")
    subject = "English"

    20.times do |idx|
      lesson = Lesson.create!(
        title: "Empty options lesson #{idx + 1}",
        external_url: "https://example.com/empty-options/#{idx + 1}",
        subject: subject,
        unit: "Unit #{(idx / 5) + 1}",
        year_group_key: child.learners.first.year_group_key,
        quizzes_json: {
          "starterQuiz" => [
            {
              "questionType" => "multiple-choice",
              "questionStem" => "Which sentence best explains the main idea?",
              "answers" => [
                { "answer" => "   ", "distractor" => true },
                { "answer" => "&nbsp;", "distractor" => true },
                { "answer" => "<b> </b>", "distractor" => false },
                { "answer" => "\n\t", "distractor" => true }
              ]
            }
          ],
          "exitQuiz" => []
        },
        summary_json: summary_payload(idx)
      )
      LessonCompletion.create!(user: child, lesson:, completed_at: Time.current - idx.minutes)
    end

    checkpoint_test = CheckpointTests::Generator.call(parent:, child:, subject:)
    mc_questions = Array(checkpoint_test.questions_json).select { |q| q["type"] == "multiple_choice" }

    assert mc_questions.any?
    assert mc_questions.none? { |q| Array(q["options"]).any? { |opt| opt.to_s.strip.blank? } }
  end

  private

  def quiz_payload(seed)
    {
      "starterQuiz" => [ build_question("Starter #{seed}") ],
      "exitQuiz" => [ build_question("Exit #{seed}") ]
    }
  end

  def build_question(label)
    {
      "questionType" => "multiple-choice",
      "questionStem" => "#{label} question?",
      "answers" => [
        { "answer" => "Correct #{label}", "distractor" => false },
        { "answer" => "Wrong A #{label}", "distractor" => true },
        { "answer" => "Wrong B #{label}", "distractor" => true }
      ]
    }
  end

  def summary_payload(seed)
    {
      "keyLearningPoints" => [
        { "keyLearningPoint" => "Key learning point #{seed}" }
      ],
      "lessonKeywords" => [
        { "keyword" => "Keyword #{seed}", "description" => "Definition #{seed}" }
      ]
    }
  end

  def create_parent(email:)
    parent = User.create!(
      email:,
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    parent.learners.create!(year_group_key: Curriculum::YearGroups.all_year_keys.first)
    parent.update!(active_learner: parent.learners.first)
    parent
  end

  def create_child(parent:, email:)
    child = User.create!(
      email:,
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent:,
      setup_completed_at: Time.current
    )
    child.learners.create!(year_group_key: Curriculum::YearGroups.all_year_keys.first)
    child.update!(active_learner: child.learners.first)
    child
  end
end
