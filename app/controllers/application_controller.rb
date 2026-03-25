class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  stale_when_importmap_changes

  before_action :ensure_onboarding_complete, if: :user_signed_in?

  helper SidebarNavHelper

  private

  def ensure_onboarding_complete
    return if devise_controller?
    return if controller_name.in?(%w[onboarding sidebar_preferences])
    return if request.path.start_with?("/rails/")

    redirect_to onboarding_path if current_user.needs_onboarding?
  end
end
