# frozen_string_literal: true

module Parent
  class FamiliesController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_parent!

    def show
      @children = current_user.children.order(:email)
      @pending_invitations = current_user.invitations.pending.order(created_at: :desc)
    end

    def child
      @child = current_user.children.find(params[:id])
      @metrics = Insights::Summary.call(viewer: current_user, scope_user: @child)
    end
  end
end
