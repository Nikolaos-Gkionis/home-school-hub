# frozen_string_literal: true

module RoleAccess
  extend ActiveSupport::Concern

  private

  def require_parent!
    return if current_user.parent?

    redirect_to role_home_path, alert: "Parent access only."
  end

  def require_child!
    return if current_user.learner?

    redirect_to role_home_path, alert: "Child access only."
  end
end
