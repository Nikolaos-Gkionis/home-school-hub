# frozen_string_literal: true

class Lesson < ApplicationRecord
  UNIT_KEY_SEP = "\u{001F}"

  OAK_SUBJECT_NAME = "Oak National Academy"
  OAK_BROWSE_UNIT = "Getting started"
  OAK_ACCOUNT_UNIT = "Account"

  YEAR_ORDER = %w[
    reception year_1 year_2 year_3 year_4 year_5 year_6
    year_7 year_8 year_9 year_10 year_11
  ].freeze

  has_many :lesson_completions, dependent: :destroy
  has_many :completing_users, through: :lesson_completions, source: :user

  validates :title, :external_url, :subject, :unit, :year_group_key, presence: true

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
    [year_key, subject, unit].join(UNIT_KEY_SEP)
  end

  def self.distinct_subjects
    distinct.order(:subject).pluck(:subject)
  end
end
