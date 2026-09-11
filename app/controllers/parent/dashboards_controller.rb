# frozen_string_literal: true

module Parent
  # Family home, plus the same wrapped Oak lesson player the child uses.
  # Inheriting DashboardController gives us hydrate_oak_lesson! so video,
  # quizzes, and downloads come from the Oak API cache — not thenational.academy.
  class DashboardsController < DashboardController
    include RoleAccess

    before_action :require_parent!

    def show
      unless hub_view_request?
        load_family_home
        render :family
        return
      end

      super
      render "dashboard/show"
    end

    private

    # Day/Week timetable, month overview, weekly calendar, or a wrapped lesson.
    def hub_view_request?
      params[:lesson_id].present? ||
        params[:overview].in?(%w[month week]) ||
        %w[day week].include?(params[:view].to_s)
    end

    def load_family_home
      @metrics = Insights::Summary.call(viewer: current_user, scope_user: nil)
      @children = current_user.children.includes(:learners, :active_learner).order(:email)
      @sent_invitations = current_user.invitations.order(created_at: :desc)
    end
  end
end
