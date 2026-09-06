# frozen_string_literal: true

class User < ApplicationRecord
  ROLE_PARENT = "parent"
  ROLE_LEARNER = "learner"

  attr_accessor :pending_invite_token

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :last_active_lesson, class_name: "Lesson", optional: true
  belongs_to :last_completed_lesson, class_name: "Lesson", optional: true
  belongs_to :active_learner, class_name: "Learner", optional: true
  belongs_to :parent, class_name: "User", optional: true

  has_many :learners, dependent: :destroy
  has_many :children, class_name: "User", foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent
  has_many :invitations, foreign_key: :parent_id, dependent: :destroy, inverse_of: :parent
  has_many :lesson_completions, dependent: :destroy
  has_many :completed_lessons, through: :lesson_completions, source: :lesson
  has_many :lesson_section_views, dependent: :destroy
  has_many :lesson_quiz_responses, dependent: :destroy
  has_many :user_badges, dependent: :destroy
  has_many :badges, through: :user_badges
  has_many :lesson_time_logs, dependent: :destroy
  has_many :unit_month_plans, dependent: :destroy
  has_many :week_lesson_slots, dependent: :destroy

  validates :current_theme, inclusion: { in: ThemeManager::PRESETS.keys }
  validates :role, inclusion: { in: [ ROLE_PARENT, ROLE_LEARNER ] }
  validate :active_learner_belongs_to_user, if: :active_learner_foreign_key_set?
  validate :role_parent_child_consistency

  before_validation :normalize_current_theme
  after_commit :consume_pending_invite, on: :create

  def parent?
    role == ROLE_PARENT
  end

  def learner?
    role == ROLE_LEARNER
  end

  def family_can_view?(other)
    return true if other.id == id
    return true if parent? && other.parent_id == id
    return true if learner? && other.id == parent_id

    false
  end

  def completed?(lesson)
    lesson_completions.exists?(lesson: lesson)
  end

  def weekly_streak
    Gamification::StreakCalculator.call(self)
  end

  def learner_year_keys
    learners.distinct.pluck(:year_group_key).compact
  end

  # The year currently shown in the lesson tree (active slot, or the first slot).
  def current_year_group_key
    active_learner&.year_group_key || learners.order(:position).first&.year_group_key
  end

  def family_display_name
    learners.order(:position).first&.display_name || email
  end

  def needs_setup?
    false
  end

  alias needs_onboarding? needs_setup?

  def visible_lessons_relation
    rel = Lesson.ordered
    years = learner_year_keys
    rel = rel.where(year_group_key: years) if years.any?
    subs = effective_preferred_subjects
    rel = rel.where(subject: subs) if subs.present?
    rel
  end

  # Sidebar subject ticks only hide the lesson tree. A calendar lesson can
  # still be opened, and its API-wrapped video / quizzes must keep working.
  def lesson_open?(lesson)
    return false if lesson.blank?

    yk = current_year_group_key
    return false if yk.present? && lesson.year_group_key != yk

    unit_unlocked?(lesson.subject, lesson.unit, year_group_key: lesson.year_group_key)
  end

  def find_open_lesson!(id)
    lesson = Lesson.find_by(id: id)
    raise ActiveRecord::RecordNotFound unless lesson_open?(lesson)

    lesson
  end

  def pacing_active?(year_group_key: current_year_group_key, academic_year: Curriculum::AcademicYear.start_year)
    return false if year_group_key.blank?

    unit_month_plans.where(year_group_key: year_group_key, academic_year: academic_year).exists?
  end

  def plan_for_unit(subject, unit, year_group_key: current_year_group_key, academic_year: Curriculum::AcademicYear.start_year)
    unit_month_plans.find_by(
      year_group_key: year_group_key,
      academic_year: academic_year,
      subject: subject,
      unit: unit
    )
  end

  # Oak "getting started" units stay open. If a parent has not made a plan yet,
  # everything stays open so existing families are not locked out.
  def unit_unlocked?(subject, unit, year_group_key: current_year_group_key)
    return true if subject.to_s == Lesson::OAK_SUBJECT_NAME
    return true unless pacing_active?(year_group_key: year_group_key)

    plan = plan_for_unit(subject, unit, year_group_key: year_group_key)
    return false if plan.nil?

    Curriculum::AcademicYear.month_unlocked?(plan.month)
  end

  def playable_lessons_relation
    rel = visible_lessons_relation
    return rel unless pacing_active?

    yk = current_year_group_key
    oak_ids = rel.where(subject: Lesson::OAK_SUBJECT_NAME).pluck(:id)
    pairs = unit_month_plans.where(
      year_group_key: yk,
      academic_year: Curriculum::AcademicYear.start_year,
      month: Curriculum::AcademicYear.unlocked_months
    ).pluck(:subject, :unit)

    assigned_ids = pairs.flat_map do |subject, unit|
      rel.where(year_group_key: yk, subject: subject, unit: unit).pluck(:id)
    end

    rel.where(id: (oak_ids + assigned_ids).uniq)
  end

  def effective_preferred_subjects
    lr = active_learner
    if lr&.preferred_subjects.present?
      arr = Array(lr.preferred_subjects).map(&:to_s).uniq
      return nil if arr.empty?

      scope_subjects = Lesson.where(year_group_key: lr.year_group_key).distinct.pluck(:subject)
      return (arr & scope_subjects).presence
    end

    return nil if preferred_subjects.nil?

    arr = Array(preferred_subjects).map(&:to_s).uniq
    return nil if arr.empty?

    all = Lesson.distinct_subjects
    (arr & all).presence
  end

  def shows_all_subjects?
    lr = active_learner
    return preferred_subjects.nil? if lr.nil? || lr.preferred_subjects.nil?

    false
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
    return nil if relation.blank?

    yk = active_learner&.year_group_key
    scoped = yk.present? ? relation.where(year_group_key: yk) : relation
    scoped.where.not(subject: Lesson::OAK_SUBJECT_NAME).first ||
      scoped.first ||
      relation.first
  end

  # A child's school year lives on a Learner row, not on the User.
  # "Move" updates that row (or activates an existing row for the new year)
  # so they see Year 8 instead of stacking a second unused year.
  def move_to_year_group!(year_key)
    yk = year_key.to_s
    unless Curriculum::YearGroups.all_year_keys.include?(yk)
      raise ArgumentError, "unknown year group: #{yk}"
    end

    target = learners.find_by(year_group_key: yk)
    if target.nil?
      primary = learners.order(:position).first
      if primary
        primary.update!(year_group_key: yk)
        target = primary
      else
        target = learners.create!(year_group_key: yk)
      end
    end

    update!(active_learner: target)
    resync_hub_after_visible_scope_change!
    target
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

  def normalize_current_theme
    self.current_theme = ThemeManager.canonical_key(current_theme)
  end

  def consume_pending_invite
    token = pending_invite_token
    return if token.blank?

    self.pending_invite_token = nil
    Invitations::AcceptInvite.call(self, token)
  end

  def role_parent_child_consistency
    if role == ROLE_PARENT && parent_id.present?
      errors.add(:parent_id, "must be blank for a parent account")
    end
    if role == ROLE_LEARNER && parent_id.blank?
      errors.add(:parent_id, "must be set for a learner account")
    end
  end

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
