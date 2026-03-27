# frozen_string_literal: true

class InsightsController < ApplicationController
  before_action :authenticate_user!

  def show
    @scope_user = resolve_scope_user
    if params[:child_id].present? && @scope_user.nil?
      redirect_to insights_path, alert: "Could not load metrics for that learner."
      return
    end

    @metrics = Insights::Summary.call(viewer: current_user, scope_user: @scope_user)
    @children = current_user.parent? ? current_user.children.order(:email).to_a : []
  end

  private

  def resolve_scope_user
    cid = params[:child_id].presence
    if cid.present?
      u = User.find_by(id: cid)
      return u if u && current_user.family_can_view?(u)

      return nil
    end

    nil
  end
end
