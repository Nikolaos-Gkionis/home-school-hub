# frozen_string_literal: true

class InsightsController < ApplicationController
  before_action :authenticate_user!

  INSIGHTS_CHILD_SESSION_KEY = :insights_child_id

  def show
    filter_id = resolve_filter_child_id

    @scope_user = resolve_scope_user(filter_id)
    if filter_id.present? && @scope_user.nil?
      session.delete(INSIGHTS_CHILD_SESSION_KEY)
      redirect_to parent_family_path, alert: "Could not load metrics for that learner."
      return
    end

    @insights_filter_id = filter_id.to_s
    @metrics = Insights::Summary.call(viewer: current_user, scope_user: @scope_user)
    @children = current_user.parent? ? current_user.children.includes(:learners).order(:email).to_a : []
  end

  private

  # Persists “which learner” for parents in the session so /insights remembers the choice.
  # All metrics still come from the database (lesson_completions, quiz responses, etc.) keyed by user id.
  def resolve_filter_child_id
    return nil unless current_user.parent?

    if params.key?(:child_id)
      if params[:child_id].present?
        session[INSIGHTS_CHILD_SESSION_KEY] = params[:child_id].to_s
      else
        session.delete(INSIGHTS_CHILD_SESSION_KEY)
      end
    end

    params[:child_id].presence || session[INSIGHTS_CHILD_SESSION_KEY].presence
  end

  def resolve_scope_user(child_id)
    return nil if child_id.blank?

    u = User.find_by(id: child_id)
    return u if u && current_user.family_can_view?(u)

    nil
  end
end
