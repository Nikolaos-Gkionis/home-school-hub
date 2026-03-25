# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :last_active_lesson, class_name: "Lesson", optional: true
  belongs_to :last_completed_lesson, class_name: "Lesson", optional: true
  belongs_to :active_learner, class_name: "Learner", optional: true

  has_many :learners, dependent: :destroy
  has_many :lesson_completions, dependent: :destroy
  has_many :completed_lessons, through: :lesson_completions, source: :lesson
  has_many :user_badges, dependent: :destroy
  has_many :badges, through: :user_badges

  validates :current_theme, inclusion: { in: ThemeManager::PRESETS.keys }
  validate :active_learner_belongs_to_user, if: :active_learner_foreign_key_set?

  def completed?(lesson)
    lesson_completions.exists?(lesson: lesson)
  end

  def weekly_streak
    Gamification::StreakCalculator.call(self)
  end

  def learner_year_keys
    learners.distinct.pluck(:year_group_key).compact
  end

  def needs_onboarding?
    learners.none?
  end

  def visible_lessons_relation
    rel = Lesson.ordered
    years = learner_year_keys
    rel = rel.where(year_group_key: years) if years.any?
    subs = effective_preferred_subjects
    rel = rel.where(subject: subs) if subs.present?
    rel
  end

  def effective_preferred_subjects
    return nil if preferred_subjects.nil?

    arr = Array(preferred_subjects).map(&:to_s).uniq
    return nil if arr.empty?

    all = Lesson.distinct_subjects
    (arr & all).presence
  end

  def shows_all_subjects?
    preferred_subjects.nil?
  end

  def sidebar_expanded_hash
    raw = sidebar_expanded.presence || {}
    h = raw.is_a?(Hash) ? raw.stringify_keys : {}
    {
      "phases" => Array(h["phases"]).map(&:to_s).uniq,
      "years" => Array(h["years"]).map(&:to_s).uniq,
      "subjects" => Array(h["subjects"]).map(&:to_s).uniq,
      "units" => Array(h["units"]).map(&:to_s).uniq
    }
  end

  def phase_expanded?(key)
    sidebar_expanded_hash["phases"].include?(key.to_s)
  end

  def year_expanded?(key)
    sidebar_expanded_hash["years"].include?(key.to_s)
  end

  def subject_expanded?(year_key, subject)
    sidebar_expanded_hash["subjects"].include?(Lesson.compose_nav_subject_key(year_key, subject))
  end

  def unit_expanded?(nav_unit_key)
    sidebar_expanded_hash["units"].include?(nav_unit_key.to_s)
  end

  def first_visible_hub_lesson_in(relation)
    rel = relation
    return nil if rel.blank?

    yk = active_learner&.year_group_key
    scoped = yk.present? ? rel.where(year_group_key: yk) : rel
    scoped.find_by(subject: Lesson::OAK_SUBJECT_NAME, unit: Lesson::OAK_BROWSE_UNIT) ||
      rel.find_by(subject: Lesson::OAK_SUBJECT_NAME, unit: Lesson::OAK_BROWSE_UNIT) ||
      scoped.first ||
      rel.first
  end

  def resync_hub_after_visible_scope_change!
    rel = visible_lessons_relation
    allowed_ids = rel.pluck(:id)
    attrs = { sidebar_expanded: pruned_sidebar_expanded_hash_for_scope }

    if last_active_lesson_id.present? && allowed_ids.exclude?(last_active_lesson_id)
      attrs[:last_active_lesson] = first_visible_hub_lesson_in(rel)
    end

    if last_completed_lesson_id.present? && allowed_ids.exclude?(last_completed_lesson_id)
      attrs[:last_completed_lesson] = nil
    end

    update!(attrs)
  end

  private

  def active_learner_foreign_key_set?
    self.class.has_attribute?(:active_learner_id) && read_attribute(:active_learner_id).present?
  end

  def active_learner_belongs_to_user
    id = read_attribute(:active_learner_id)
    return if learners.exists?(id: id)

    errors.add(:active_learner_id, "must be one of your learners")
  end

  def pruned_sidebar_expanded_hash_for_scope
    h = sidebar_expanded_hash
    years_set = learner_year_keys.to_set
    allowed_phases = Curriculum::YearGroups.phases_for_years(learner_year_keys).map { |p| p[:key].to_s }.to_set
    subs = effective_preferred_subjects

    {
      "phases" => h["phases"].select { |pk| allowed_phases.include?(pk) },
      "years" => h["years"].select { |yk| years_set.include?(yk) },
      "subjects" => h["subjects"].select do |nav_key|
        parts = nav_key.split(Lesson::UNIT_KEY_SEP, 2)
        next false if parts.size < 2

        yk, subj = parts
        years_set.include?(yk) && (subs.nil? || subs.include?(subj))
      end,
      "units" => h["units"].select do |nav_key|
        parts = nav_key.split(Lesson::UNIT_KEY_SEP)
        next false if parts.size < 3

        yk, subj = parts[0], parts[1]
        years_set.include?(yk) && (subs.nil? || subs.include?(subj))
      end
    }
  end
end
