# frozen_string_literal: true

class LearnersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_parent!

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
    redirect_to dashboard_path, notice: "Added #{Curriculum::YearGroups.label_for_year(yk)}."
  end

  def activate
    learner = current_user.learners.find(params[:id])
    current_user.update!(active_learner: learner)
    redirect_back fallback_location: dashboard_path
  end

  def destroy
    learner = current_user.learners.find(params[:id])
    label = learner.display_name
    was_active = current_user.active_learner_id == learner.id
    learner.destroy!
    if was_active
      nxt = current_user.learners.order(:position).first
      current_user.update!(active_learner: nxt)
    end
    current_user.resync_hub_after_visible_scope_change!
    redirect_to dashboard_path, notice: "Removed #{label} from your school years."
  end

  private

  def ensure_parent!
    redirect_to dashboard_path, alert: "Only parent accounts can manage school years." unless current_user.parent?
  end
end
