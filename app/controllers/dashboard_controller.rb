# frozen_string_literal: true

class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @lessons = current_user.visible_lessons_relation
    @lesson = find_lesson
    persist_lesson_context! if @lesson
  end

  private

  def find_lesson
    rel = current_user.visible_lessons_relation
    yk = current_user.active_learner&.year_group_key

    lesson = rel.find_by(id: params[:lesson_id]) if params[:lesson_id].present?

    if lesson.nil? && current_user.last_active_lesson_id.present?
      la = rel.find_by(id: current_user.last_active_lesson_id)
      lesson = la if la && (yk.blank? || la.year_group_key == yk)
    end

    lesson || default_starting_lesson(rel)
  end

  def default_starting_lesson(rel)
    current_user.first_visible_hub_lesson_in(rel)
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
        "phases" => (h["phases"] + [pk.to_s]).compact.uniq,
        "years" => (h["years"] + [@lesson.year_group_key.to_s]).compact.uniq,
        "subjects" => (h["subjects"] + [nav_subj]).uniq,
        "units" => (h["units"] + [nav_unit]).uniq
      }
    end
    current_user.update!(attrs)
  end
end
