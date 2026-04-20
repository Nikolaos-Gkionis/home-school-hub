# frozen_string_literal: true

class SidebarPreferencesController < ApplicationController
  before_action :authenticate_user!

  def update
    if json_sidebar_request?
      apply_json_sidebar!
      return head :ok
    end

    if params.key?(:preferred_subjects)
      update_preferred_subjects_from_form!
      current_user.resync_hub_after_visible_scope_change!
      respond_to do |format|
        format.json { head :ok }
        format.html { redirect_to role_home_path, notice: "Subjects updated." }
      end
      return
    end

    redirect_back fallback_location: role_home_path, notice: "Subjects updated."
  end

  private

  def json_sidebar_request?
    request.format.json? || request.media_type == Mime[:json]
  end

  def apply_json_sidebar!
    body = request.raw_post.presence
    if body.blank? && request.body.respond_to?(:read)
      body = request.body.read
      request.body.rewind if request.body.respond_to?(:rewind)
    end
    return head :ok if body.blank?

    data = JSON.parse(body)
    exp = data["sidebar_expanded"]
    return head :ok if exp.blank?

    current_user.update!(
      sidebar_expanded: {
        "phases" => Array(exp["phases"]).map(&:to_s).uniq,
        "years" => Array(exp["years"]).map(&:to_s).uniq,
        "subjects" => Array(exp["subjects"]).map(&:to_s).uniq,
        "units" => Array(exp["units"]).map(&:to_s).uniq
      }
    )
  rescue JSON::ParserError
    head :bad_request
  end

  def update_preferred_subjects_from_form!
    all = OakCurriculum.hub_subject_filter_options
    chosen = Array(params[:preferred_subjects]).map(&:to_s).reject(&:blank?).uniq.sort
    if chosen.empty?
      current_user.update!(preferred_subjects: nil)
      return
    end

    current_user.update!(preferred_subjects: chosen == all ? nil : chosen)
  end
end
