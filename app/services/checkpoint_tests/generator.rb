# frozen_string_literal: true

require "set"

module CheckpointTests
  class Generator
    MULTIPLE_CHOICE_RATIO = 0.7

    class Error < StandardError; end

    class << self
      def call(parent:, child:, subject:)
        new(parent:, child:, subject:).call
      end
    end

    def initialize(parent:, child:, subject:)
      @parent = parent
      @child = child
      @subject = subject.to_s
    end

    def call
      raise Error, "Subject is required." if @subject.blank?

      completed = completed_lesson_rows
      if completed.size < CheckpointTest::MIN_COMPLETED_LESSONS
        raise Error, "A checkpoint test needs at least #{CheckpointTest::MIN_COMPLETED_LESSONS} completed lessons in this subject."
      end

      questions = build_questions(completed.map(&:lesson))
      if questions.size < CheckpointTest::QUESTION_MIN
        raise Error, "Not enough lesson content yet to generate a printable test."
      end

      CheckpointTest.create!(
        parent: @parent,
        child: @child,
        subject: @subject,
        completed_lessons_count: completed.size,
        question_count: questions.size,
        units_json: completed.map { |row| row.lesson.unit.to_s }.uniq,
        questions_json: questions
      )
    end

    private

    def completed_lesson_rows
      LessonCompletion.includes(:lesson)
                      .joins(:lesson)
                      .where(user: @child, lessons: { subject: @subject })
                      .order(completed_at: :desc)
    end

    def build_questions(lessons)
      mc_pool = multiple_choice_pool(lessons)
      free_pool = free_text_pool(lessons)
      target = CheckpointTest::TARGET_QUESTION_COUNT

      mc_target = [ (target * MULTIPLE_CHOICE_RATIO).round, mc_pool.size ].min
      free_target = [ target - mc_target, free_pool.size ].min
      remaining = target - (mc_target + free_target)

      if remaining.positive?
        add_mc = [ remaining, mc_pool.size - mc_target ].min
        mc_target += add_mc
        remaining -= add_mc
      end

      if remaining.positive?
        add_free = [ remaining, free_pool.size - free_target ].min
        free_target += add_free
      end

      selected = mc_pool.first(mc_target) + free_pool.first(free_target)
      selected = selected.first(CheckpointTest::QUESTION_MAX)
      selected = selected.first(CheckpointTest::QUESTION_MIN) if selected.size > CheckpointTest::QUESTION_MIN && selected.size < CheckpointTest::TARGET_QUESTION_COUNT
      selected.shuffle
    end

    def multiple_choice_pool(lessons)
      seen = Set.new
      rows = []

      lessons.each do |lesson|
        quiz = lesson.quizzes_json.is_a?(Hash) ? lesson.quizzes_json : {}
        %w[starterQuiz exitQuiz].each do |key|
          Array(quiz[key]).each do |question|
            next unless question["questionType"].to_s == "multiple-choice"

            prompt = question["questionStem"].to_s.strip
            next if prompt.blank?
            next if seen.include?(prompt.downcase)

            options = Array(question["answers"]).map { |a| a["answer"].to_s.strip }.reject(&:blank?)
            next if options.size < 2

            correct_letters = Array(question["answers"]).each_with_index.filter_map do |answer, idx|
              ("A".ord + idx).chr if answer["distractor"] == false
            end
            next if correct_letters.empty?

            rows << {
              "type" => "multiple_choice",
              "prompt" => prompt,
              "options" => options,
              "answer" => correct_letters.join(", "),
              "unit" => lesson.unit.to_s,
              "lesson_title" => lesson.title.to_s
            }
            seen << prompt.downcase
          end
        end
      end

      rows
    end

    def free_text_pool(lessons)
      seen = Set.new
      rows = []

      lessons.each do |lesson|
        summary = lesson.summary_data

        Array(summary["keyLearningPoints"]).each do |row|
          text = row.is_a?(Hash) ? row["keyLearningPoint"].to_s.strip : row.to_s.strip
          next if text.blank?
          next if seen.include?(text.downcase)

          rows << {
            "type" => "free_text",
            "prompt" => "Explain this idea in your own words: #{text}",
            "answer" => text,
            "unit" => lesson.unit.to_s,
            "lesson_title" => lesson.title.to_s
          }
          seen << text.downcase
        end

        Array(summary["lessonKeywords"]).each do |kw|
          keyword = kw.is_a?(Hash) ? kw["keyword"].to_s.strip : kw.to_s.strip
          definition = kw.is_a?(Hash) ? kw["description"].to_s.strip : ""
          next if keyword.blank? || definition.blank?
          dedupe_key = "#{keyword.downcase}:#{definition.downcase}"
          next if seen.include?(dedupe_key)

          rows << {
            "type" => "free_text",
            "prompt" => "Define '#{keyword}' and use it in one sentence.",
            "answer" => definition,
            "unit" => lesson.unit.to_s,
            "lesson_title" => lesson.title.to_s
          }
          seen << dedupe_key
        end
      end

      rows
    end
  end
end
