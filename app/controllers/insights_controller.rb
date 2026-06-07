# frozen_string_literal: true

class InsightsController < ApplicationController
  before_action :authenticate_user!

  INSIGHTS_CHILD_SESSION_KEY = :insights_child_id
  DAILY_DATES_PER_PAGE = 5

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
    @daily_dates_per_page = DAILY_DATES_PER_PAGE
    assign_daily_date_page!
    @children = current_user.parent? ? current_user.children.includes(:learners).order(:email).to_a : []
    @checkpoint_child =
      if current_user.parent? && @scope_user&.learner?
        @scope_user
      elsif current_user.parent? && current_user.children.none?
        current_user
      end
    @eligible_checkpoint_subjects = @checkpoint_child ? CheckpointTest.eligible_subjects_for(@checkpoint_child) : []
    @recent_checkpoint_tests =
      if @checkpoint_child
        CheckpointTest.where(parent: current_user, child: @checkpoint_child).recent_first.limit(10)
      else
        []
      end
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

  def assign_daily_date_page!
    all_dates = (@metrics[:daily_lesson_dates] + @metrics[:daily_time_dates]).uniq.sort
    @daily_dates_total_count = all_dates.size
    @daily_dates = []
    @daily_dates_page = 1
    @daily_dates_total_pages = 0
    return if all_dates.empty?

    per_page = DAILY_DATES_PER_PAGE
    @daily_dates_total_pages = (all_dates.size.to_f / per_page).ceil
    @daily_dates_page = params.fetch(:daily_page, 1).to_i
    @daily_dates_page = 1 if @daily_dates_page < 1
    @daily_dates_page = @daily_dates_total_pages if @daily_dates_page > @daily_dates_total_pages

    end_index = all_dates.size - ((@daily_dates_page - 1) * per_page)
    start_index = [ end_index - per_page, 0 ].max
    @daily_dates = all_dates[start_index...end_index] || []
  end
end
