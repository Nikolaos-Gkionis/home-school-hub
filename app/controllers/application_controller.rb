class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  stale_when_importmap_changes

  before_action :ensure_setup_complete, if: :user_signed_in?
  before_action :configure_permitted_parameters, if: :devise_controller?

  helper SidebarNavHelper

  def after_sign_in_path_for(_resource)
    role_home_path
  end

  private

  def ensure_setup_complete
    return if devise_controller?
    return if controller_name.in?(%w[
      pages invitations legacy_redirects sidebar_preferences setup
      lesson_completions lesson_progresses oak_assets lesson_time_logs themes
    ])
    return if request.path.start_with?("/rails/")
    return if request.path.start_with?("/invitations/accept")

    redirect_to setup_years_path if current_user.parent? && current_user.needs_setup?
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :invite_token ])
  end

  def role_home_path(user = current_user)
    user.parent? ? parent_dashboard_path : child_dashboard_path
  end

  def role_dashboard_path(user = current_user, lesson_id: nil)
    if user.parent?
      parent_dashboard_path(lesson_id: lesson_id)
    else
      child_dashboard_path(lesson_id: lesson_id)
    end
  end

  def role_insights_path(user = current_user)
    user.parent? ? insights_path : child_profile_path
  end
end
