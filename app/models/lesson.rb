# frozen_string_literal: true

class Lesson < ApplicationRecord
  UNIT_KEY_SEP = "\u{001F}"

  OAK_SUBJECT_NAME = "Oak National Academy"
  OAK_BROWSE_UNIT = "Getting started"
  OAK_ACCOUNT_UNIT = "Account"

  CONTENT_MODE_LEGACY = "legacy_iframe"
  CONTENT_MODE_OAK_HUB = "oak_hub"

  # Tracked in LessonSectionView for Oak hub lessons (render order in dashboard).
  HUB_SECTION_KEYS = %w[
    overview keywords video downloads misconceptions outcome teacher_tips
    starter_quiz exit_quiz content_guidance supervision transcript
  ].freeze

  YEAR_ORDER = %w[
    reception year_1 year_2 year_3 year_4 year_5 year_6
    year_7 year_8 year_9 year_10 year_11
  ].freeze

  has_many :lesson_completions, dependent: :destroy
  has_many :completing_users, through: :lesson_completions, source: :user
  has_many :lesson_section_views, dependent: :destroy
  has_many :lesson_quiz_responses, dependent: :destroy
  has_many :lesson_time_logs, dependent: :destroy

  validates :title, :external_url, :subject, :unit, :year_group_key, presence: true
  validates :content_mode, inclusion: { in: [ CONTENT_MODE_LEGACY, CONTENT_MODE_OAK_HUB ] }

  scope :ordered, -> {
    t = arel_table
    year_rank = Arel::Nodes::Case.new(t[:year_group_key])
    YEAR_ORDER.each_with_index { |yk, i| year_rank.when(t[:year_group_key].eq(yk)).then(i) }
    year_rank.else(99)
    unit_order = Arel::Nodes::NamedFunction.new(
      "COALESCE",
      [ t[:unit_position], Arel::Nodes.build_quoted(9999) ]
    )
    order(year_rank, t[:subject], unit_order, t[:unit], t[:position], t[:id])
  }

  def self.compose_unit_key(subject, unit)
    "#{subject}#{UNIT_KEY_SEP}#{unit}"
  end

  def self.compose_nav_subject_key(year_key, subject)
    "#{year_key}#{UNIT_KEY_SEP}#{subject}"
  end

  def self.compose_nav_unit_key(year_key, subject, unit)
    [ year_key, subject, unit ].join(UNIT_KEY_SEP)
  end

  def self.distinct_subjects
    distinct.order(:subject).pluck(:subject)
  end

  def oak_hub?
    content_mode == CONTENT_MODE_OAK_HUB && oak_lesson_slug.present?
  end

  def legacy_iframe?
    !oak_hub?
  end

  def oak_pupil_lesson_url
    return external_url if oak_lesson_slug.blank?

    "https://www.thenational.academy/pupils/lessons/#{oak_lesson_slug}"
  end

  def summary_data
    summary_json.is_a?(Hash) ? summary_json : {}
  end

  def assets_list
    h = assets_json
    return [] unless h.is_a?(Hash)

    Array(h["assets"])
  end

  def assets_attributions
    h = assets_json
    return [] unless h.is_a?(Hash)

    Array(h["attribution"]).map(&:to_s).reject(&:blank?)
  end

  def downloadable_asset_rows
    assets_list.reject { |a| a["type"].to_s == "video" }
  end

  def transcript_excerpt
    t = transcript_json
    return "" unless t.is_a?(Hash)

    t["transcript"].to_s
  end

  def hub_section_visible?(key)
    s = summary_data
    q = quizzes_json.is_a?(Hash) ? quizzes_json : {}
    case key
    when "overview"
      true
    when "keywords"
      s["lessonKeywords"].present?
    when "video"
      assets_list.any? { |a| a["type"].to_s == "video" }
    when "downloads"
      downloadable_asset_rows.any?
    when "misconceptions"
      s["misconceptionsAndCommonMistakes"].present?
    when "outcome"
      s["keyLearningPoints"].present?
    when "teacher_tips"
      s["teacherTips"].present?
    when "starter_quiz"
      Array(q["starterQuiz"]).any? { |qu| qu["questionType"].to_s == "multiple-choice" }
    when "exit_quiz"
      Array(q["exitQuiz"]).any? { |qu| qu["questionType"].to_s == "multiple-choice" }
    when "content_guidance"
      s["contentGuidance"].present?
    when "supervision"
      s["supervisionLevel"].present?
    when "transcript"
      transcript_excerpt.present?
    else
      false
    end
  end

  def hub_section_keys_for_lesson
    HUB_SECTION_KEYS.select { |k| hub_section_visible?(k) }
  end

  def hub_section_progress_for(user)
    keys = hub_section_keys_for_lesson
    seen = lesson_section_views.where(user: user, section_key: keys).distinct.count(:section_key)
    { seen:, total: [ keys.size, 1 ].max }
  end

  def quiz_mc_total_count
    q = quizzes_json.is_a?(Hash) ? quizzes_json : {}
    %w[starterQuiz exitQuiz].sum do |key|
      Array(q[key]).count { |qu| qu["questionType"].to_s == "multiple-choice" }
    end
  end

  def quiz_mc_progress_for(user)
    rows = lesson_quiz_responses.where(user: user)
    { answered: rows.count, correct: rows.where(correct: true).count, total: quiz_mc_total_count }
  end
end
