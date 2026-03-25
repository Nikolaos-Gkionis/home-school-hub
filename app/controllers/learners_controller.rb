# frozen_string_literal: true

class LearnersController < ApplicationController
  before_action :authenticate_user!

  def new
    @phases = Curriculum::YearGroups::PHASES
    @taken = current_user.learner_year_keys.to_set
  end

  def create
    yk = params[:year_group_key].to_s
    unless Curriculum::YearGroups.all_year_keys.include?(yk)
      redirect_to new_learner_path, alert: "That school year is not available."
      return
    end
    if current_user.learners.exists?(year_group_key: yk)
      redirect_to new_learner_path, alert: "That year is already in your list."
      return
    end

    current_user.learners.create!(year_group_key: yk)
    redirect_to root_path, notice: "Added #{Curriculum::YearGroups.label_for_year(yk)}."
  end

  def activate
    learner = current_user.learners.find(params[:id])
    current_user.update!(active_learner: learner)
    redirect_back fallback_location: root_path
  end
end
