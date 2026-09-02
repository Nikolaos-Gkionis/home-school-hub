# frozen_string_literal: true

module Parent
  class DashboardsController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_parent!

    def show
      @metrics = Insights::Summary.call(viewer: current_user, scope_user: nil)
      @children = current_user.children.includes(:learners, :active_learner).order(:email)
      @sent_invitations = current_user.invitations.order(created_at: :desc)
    end
  end
end
