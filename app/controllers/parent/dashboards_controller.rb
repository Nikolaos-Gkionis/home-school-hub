# frozen_string_literal: true

module Parent
  # Family home, plus the same wrapped Oak lesson player the child uses.
  # Inheriting DashboardController gives us hydrate_oak_lesson! so video,
  # quizzes, and downloads come from the Oak API cache — not thenational.academy.
  class DashboardsController < DashboardController
    include RoleAccess

    before_action :require_parent!

    def show
      if params[:lesson_id].present?
        show_wrapped_lesson
        return
      end

      @metrics = Insights::Summary.call(viewer: current_user, scope_user: nil)
      @children = current_user.children.includes(:learners, :active_learner).order(:email)
      @sent_invitations = current_user.invitations.order(created_at: :desc)
    end

    private

    def show_wrapped_lesson
      @lesson = Lesson.find_by(id: params[:lesson_id])
      if @lesson.blank?
        redirect_to parent_dashboard_path, alert: "That lesson could not be found."
        return
      end

      hydrate_oak_lesson!
      render "dashboard/show"
    end
  end
end
