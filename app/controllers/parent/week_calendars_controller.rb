# frozen_string_literal: true

module Parent
  class WeekCalendarsController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_parent!
    before_action :set_child

    def show
      @calendar = Curriculum::WeekCalendar.call(
        child: @child,
        month: selected_month,
        week_monday: params[:week],
        completed_lesson_ids: @child.lesson_completions.pluck(:lesson_id)
      )
    end

    private

    def set_child
      @child = current_user.children.find(params[:child_id])
    end

    def selected_month
      month = params[:month].to_i
      Curriculum::AcademicYear.plan_month?(month) ? month : Curriculum::AcademicYear.current_month
    end
  end
end
