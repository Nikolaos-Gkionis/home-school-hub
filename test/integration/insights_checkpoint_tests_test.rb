# frozen_string_literal: true

require "test_helper"

class InsightsCheckpointTestsTest < ActionDispatch::IntegrationTest
  def test_insights_shows_checkpoint_button_for_selected_child
    parent = create_parent(email: "parent-insights-checkpoint@example.com")
    child = create_child(parent:, email: "child-insights-checkpoint@example.com")
    subject = "English"

    20.times do |idx|
      lesson = Lesson.create!(
        title: "English lesson #{idx + 1}",
        external_url: "https://example.com/english/#{idx + 1}",
        subject: subject,
        unit: "Unit #{(idx / 5) + 1}",
        year_group_key: child.learners.first.year_group_key
      )
      LessonCompletion.create!(user: child, lesson:, completed_at: Time.current - idx.minutes)
    end

    sign_in_as(parent)
    get insights_path, params: { child_id: child.id }

    assert_response :success
    assert_includes response.body, "Checkpoint tests"
    assert_includes response.body, "Create English checkpoint"
  end

  def test_insights_shows_checkpoint_button_for_parent_account_when_no_child_accounts_exist
    parent = create_parent(email: "parent-insights-self-checkpoint@example.com")
    subject = "Maths"

    20.times do |idx|
      lesson = Lesson.create!(
        title: "Maths lesson #{idx + 1}",
        external_url: "https://example.com/maths/#{idx + 1}",
        subject: subject,
        unit: "Unit #{(idx / 5) + 1}",
        year_group_key: parent.learners.first.year_group_key,
        quizzes_json: quiz_payload(idx),
        summary_json: summary_payload(idx)
      )
      LessonCompletion.create!(user: parent, lesson:, completed_at: Time.current - idx.minutes)
    end

    sign_in_as(parent)
    get insights_path

    assert_response :success
    assert_includes response.body, "Checkpoint tests"
    assert_includes response.body, "Create Maths checkpoint"

    post parent_child_checkpoint_tests_path(parent), params: { subject: subject }
    checkpoint_test = CheckpointTest.order(:id).last
    assert_redirected_to parent_child_checkpoint_test_path(parent, checkpoint_test)
  end

  private

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

  def sign_in_as(user)
    post user_session_path, params: {
      user: { email: user.email, password: "Password123!" }
    }
  end

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
end
