# frozen_string_literal: true

class OnboardingController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_if_complete

  def show
    @phases = Curriculum::YearGroups::PHASES
  end

  def create
    keys = Array(params[:year_group_keys]).map(&:to_s).uniq & Curriculum::YearGroups.all_year_keys
    if keys.empty?
      redirect_to onboarding_path, alert: "Choose at least one school year to continue."
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

    redirect_to root_path, notice: 'School years saved. Use "Add a year" in the sidebar if you need another later.'
  end

  private

  def redirect_if_complete
    redirect_to root_path unless current_user.needs_onboarding?
  end
end
