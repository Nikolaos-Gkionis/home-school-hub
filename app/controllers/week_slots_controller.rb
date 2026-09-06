# frozen_string_literal: true

class WeekSlotsController < ApplicationController
  include RoleAccess

  before_action :authenticate_user!
  before_action :set_child

  def swap
    ok = Curriculum::WeekCalendar.swap!(
      child: @child,
      from_date: params[:from_date],
      from_period: params[:from_period],
      to_date: params[:to_date],
      to_period: params[:to_period],
      month: selected_month,
      week_monday: params[:week]
    )

    if ok
      redirect_to week_return_path, notice: "Moved that lesson."
    else
      redirect_to week_return_path, alert: "Those two slots could not be swapped."
    end
  end

  def reset
    monday = Date.iso8601(params[:week].to_s) rescue Curriculum::AcademicYear.monday_of(Date.current)
    dates = Curriculum::AcademicYear.school_dates_for_monday(monday, selected_month, Curriculum::AcademicYear.start_year)
    Curriculum::WeekCalendar.reset_week!(child: @child, dates: dates)
    redirect_to week_return_path, notice: "Put this week back to the automatic timetable."
  end

  private

  def set_child
    @child = if current_user.parent?
      current_user.children.find(params[:child_id])
    else
      current_user
    end
  end

  def selected_month
    month = params[:month].to_i
    Curriculum::AcademicYear.plan_month?(month) ? month : Curriculum::AcademicYear.current_month
  end

  def week_return_path
    if current_user.parent?
      parent_child_week_path(@child, month: selected_month, week: params[:week])
    else
      child_dashboard_path(overview: "week", month: selected_month, week: params[:week])
    end
  end
end
