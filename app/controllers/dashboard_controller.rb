# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @lessons = visible_lessons_with_auto_sync
    if params[:overview] == "month"
      @month_overview = true
      @lesson = nil
      load_month_overview
      return
    end

    if params[:overview] == "week"
      @week_overview = true
      @lesson = nil
      load_week_overview
      return
    end

    @lesson = find_lesson
    hydrate_oak_lesson! if @lesson
    persist_lesson_context! if @lesson
  end

  private

  def visible_lessons_with_auto_sync
    rel = current_user.visible_lessons_relation
    return rel if rel.exists?
    return rel unless Oak::ApiClient.configured?

    # If no lessons are present yet, bootstrap this learner's year from Oak.
    # Do not hydrate the whole catalogue here — that is what tripped Oak's rate limit.
    yk = current_user.active_learner&.year_group_key
    return rel if yk.blank?

    Oak::Importer.call(year_groups: [ yk ], hydrate: false)
    current_user.visible_lessons_relation
  rescue StandardError => e
    Rails.logger.warn("[DashboardController] auto-sync failed: #{e.class}: #{e.message}")
    rel
  end

  def find_lesson
    rel = current_user.playable_lessons_relation
    yk = current_user.active_learner&.year_group_key

    # Honour the clicked lesson id first. Subject filters must not send the
    # child to a different lesson than the one on the calendar block.
    if params[:lesson_id].present?
      requested = Lesson.find_by(id: params[:lesson_id])
      return requested if requested && lesson_open_for_child?(requested, yk)
    end

    if current_user.last_active_lesson_id.present?
      la = rel.find_by(id: current_user.last_active_lesson_id)
      return la if la && (yk.blank? || la.year_group_key == yk)
    end

    default_starting_lesson(rel)
  end

  def lesson_open_for_child?(lesson, year_key)
    return false if year_key.present? && lesson.year_group_key != year_key

    current_user.unit_unlocked?(lesson.subject, lesson.unit, year_group_key: lesson.year_group_key)
  end

  def default_starting_lesson(rel)
    current_user.first_visible_hub_lesson_in(rel)
  end

  def load_month_overview
    @plan_month = Curriculum::AcademicYear.current_month
    @plan_month_label = Curriculum::AcademicYear.label_for(@plan_month)
    yk = current_user.current_year_group_key
    @month_units = []
    return if yk.blank?

    completed = current_user.lesson_completions.pluck(:lesson_id).to_set
    plans = if current_user.pacing_active?
      current_user.unit_month_plans.where(
        year_group_key: yk,
        academic_year: Curriculum::AcademicYear.start_year,
        month: @plan_month
      )
    else
      []
    end

    units = if plans.present?
      plans.map { |plan| { subject: plan.subject, unit: plan.unit } }
    else
      Lesson.where(year_group_key: yk)
        .where.not(subject: Lesson::OAK_SUBJECT_NAME)
        .select(:subject, :unit, :unit_position)
        .group_by { |l| [ l.subject, l.unit ] }
        .keys
        .first(12)
        .map { |subject, unit| { subject: subject, unit: unit } }
    end

    @month_units = units.map do |row|
      lessons = Lesson.where(year_group_key: yk, subject: row[:subject], unit: row[:unit]).ordered
      ids = lessons.map(&:id)
      done = ids.count { |id| completed.include?(id) }
      row.merge(
        lessons: lessons,
        done: done,
        total: ids.size,
        first_lesson: lessons.first
      )
    end
  end

  def load_week_overview
    @calendar = Curriculum::WeekCalendar.call(
      child: current_user,
      month: selected_week_month,
      week_monday: params[:week],
      completed_lesson_ids: current_user.lesson_completions.pluck(:lesson_id)
    )
  end

  def selected_week_month
    month = params[:month].to_i
    return Curriculum::AcademicYear.current_month unless Curriculum::AcademicYear.plan_month?(month)
    return Curriculum::AcademicYear.current_month if current_user.pacing_active? && !Curriculum::AcademicYear.month_unlocked?(month)

    month
  end

  def hydrate_oak_lesson!
    return unless @lesson.oak_hub?
    return unless Oak::ApiClient.configured?

    needs_fill = !(@lesson.summary_json.is_a?(Hash) && @lesson.summary_json["lessonTitle"].present?)
    stale = Oak::LessonHydrator.stale?(@lesson)
    return unless needs_fill || stale

    result = Oak::LessonHydrator.call(@lesson)
    @lesson.reload
    flash.now[:alert] = result.user_message if result.failure? && result.user_message.present?
  end

  def persist_lesson_context!
    h = current_user.sidebar_expanded_hash
    expand = params[:lesson_id].present? || (h["subjects"].empty? && h["units"].empty?)
    attrs = { last_active_lesson: @lesson }
    if expand
      pk = Curriculum::YearGroups.phase_key_for_year(@lesson.year_group_key)
      nav_subj = Lesson.compose_nav_subject_key(@lesson.year_group_key, @lesson.subject)
      nav_unit = Lesson.compose_nav_unit_key(@lesson.year_group_key, @lesson.subject, @lesson.unit)
      attrs[:sidebar_expanded] = {
        "phases" => (h["phases"] + [ pk.to_s ]).compact.uniq,
        "years" => (h["years"] + [ @lesson.year_group_key.to_s ]).compact.uniq,
        "subjects" => (h["subjects"] + [ nav_subj ]).uniq,
        "units" => (h["units"] + [ nav_unit ]).uniq
      }
    end
    current_user.update!(attrs)
  end
end
