# frozen_string_literal: true

class SetupController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_learners
  before_action :redirect_if_done, only: %i[years subjects]

  def years
    @phases = Curriculum::YearGroups::PHASES
  end

  def save_years
    keys = Array(params[:year_group_keys]).map(&:to_s).uniq & Curriculum::YearGroups.all_year_keys
    if keys.empty?
      redirect_to setup_years_path, alert: "Choose at least one school year."
      return
    end

    ActiveRecord::Base.transaction do
      current_user.learners.destroy_all
      keys.each_with_index do |yk, i|
        current_user.learners.create!(year_group_key: yk, position: i)
      end
      first = current_user.learners.order(:position).first
      current_user.update!(active_learner: first)
    end

    redirect_to setup_subjects_path
  end

  def subjects
    redirect_to setup_years_path, alert: "Choose years first." if current_user.learners.none?

    @learners = current_user.learners.order(:position)
    @subject_options = subject_options
  end

  def save_subjects
    redirect_to setup_years_path, alert: "Choose years first." if current_user.learners.none?

    opts = subject_options
    hash = params[:preferred_subjects] || {}
    current_user.learners.each do |lr|
      chosen = Array(hash[lr.id.to_s]).map(&:to_s).uniq
      if chosen.empty? || (opts.any? && chosen.length >= opts.length)
        lr.update!(preferred_subjects: nil)
      else
        lr.update!(preferred_subjects: chosen)
      end
    end

    current_user.update!(setup_completed_at: Time.current)
    redirect_to dashboard_path, notice: "Your curriculum is set. You can change subjects anytime from the sidebar."
  end

  private

  def redirect_learners
    redirect_to dashboard_path if current_user.learner?
  end

  def redirect_if_done
    redirect_to dashboard_path unless current_user.needs_setup?
  end

  def subject_options
    @subject_options ||= OakCurriculum.hub_subject_filter_options
  end
end
