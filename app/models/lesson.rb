# frozen_string_literal: true

class Lesson < ApplicationRecord
  UNIT_KEY_SEP = "\u{001F}"

  OAK_SUBJECT_NAME = "Oak National Academy"
  OAK_BROWSE_UNIT = "Getting started"
  OAK_ACCOUNT_UNIT = "Account"

  CONTENT_MODE_LEGACY = "legacy_iframe"
  CONTENT_MODE_OAK_HUB = "oak_hub"

  # Tracked in LessonSectionView for Oak hub lessons (order matches dashboard sections).
  HUB_SECTION_KEYS = %w[
    overview keywords video misconceptions outcome teacher_tips starter_quiz exit_quiz
  ].freeze

  YEAR_ORDER = %w[
    reception year_1 year_2 year_3 year_4 year_5 year_6
    year_7 year_8 year_9 year_10 year_11
  ].freeze

  has_many :lesson_completions, dependent: :destroy
  has_many :completing_users, through: :lesson_completions, source: :user
  has_many :lesson_section_views, dependent: :destroy
  has_many :lesson_quiz_responses, dependent: :destroy

  validates :title, :external_url, :subject, :unit, :year_group_key, presence: true
  validates :content_mode, inclusion: { in: [ CONTENT_MODE_LEGACY, CONTENT_MODE_OAK_HUB ] }

  scope :ordered, -> {
    conn = connection
    cases = YEAR_ORDER.map.with_index { |yk, i| "WHEN #{conn.quote(yk)} THEN #{i}" }.join(" ")
    order(Arel.sql("CASE #{table_name}.year_group_key #{cases} ELSE 99 END, #{table_name}.subject, #{table_name}.unit, #{table_name}.position, #{table_name}.id"))
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

  def hub_section_progress_for(user)
    seen = lesson_section_views.where(user: user).distinct.count(:section_key)
    { seen:, total: HUB_SECTION_KEYS.size }
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
