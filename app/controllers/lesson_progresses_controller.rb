# frozen_string_literal: true

class LessonProgressesController < ApplicationController
  before_action :authenticate_user!

  def record_section
    lesson = find_lesson
    key = params[:section_key].to_s
    return head :bad_request unless Lesson::HUB_SECTION_KEYS.include?(key)

    now = Time.current
    row = LessonSectionView.find_or_initialize_by(user: current_user, lesson: lesson, section_key: key)
    row.first_seen_at ||= now
    row.last_seen_at = now
    row.save!

    head :ok
  end

  def record_quiz
    lesson = find_lesson
    quiz_type = params[:quiz_type].to_s
    return head :bad_request unless LessonQuizResponse::QUIZ_TYPES.include?(quiz_type)

    qidx = params[:question_index].to_i
    raw = params[:answer_indices]
    indices =
      if raw.is_a?(Array)
        raw.map(&:to_i)
      elsif raw.present?
        [ raw.to_i ]
      else
        []
      end

    quiz = lesson.quizzes_json.is_a?(Hash) ? lesson.quizzes_json : {}
    key = quiz_type == "starter" ? "starterQuiz" : "exitQuiz"
    questions = Array(quiz[key]).select { |q| q["questionType"].to_s == "multiple-choice" }
    question = questions[qidx]
    return head :not_found if question.blank?

    correct = Oak::QuizScorer.multiple_choice_correct?(question, indices)

    lr = LessonQuizResponse.find_or_initialize_by(
      user_id: current_user.id,
      lesson_id: lesson.id,
      quiz_type: quiz_type,
      question_index: qidx
    )
    lr.assign_attributes(answer_indices: indices, correct: correct)
    lr.save!

    redirect_to dashboard_path(lesson_id: lesson.id)
  end

  private

  def find_lesson
    current_user.visible_lessons_relation.find(params[:lesson_id])
  end
end
