# frozen_string_literal: true

module Oak
  # Scores Oak quiz payloads (multiple-choice questions only).
  module QuizScorer
    module_function

    def multiple_choice_correct?(question, selected_indices)
      return false unless question.is_a?(Hash)
      return false if question["questionType"].to_s != "multiple-choice"

      answers = Array(question["answers"])
      correct = answers.each_with_index.filter_map { |a, i| i if a["distractor"] == false }.to_set
      selected = Array(selected_indices).map(&:to_i).to_set
      correct == selected && correct.any?
    end
  end
end
