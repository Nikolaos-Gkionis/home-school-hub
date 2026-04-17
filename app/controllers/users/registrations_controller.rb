# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    layout :registration_layout

    protected

    def after_sign_up_path_for(resource)
      resource.reload
      return child_dashboard_path if resource.learner?

      setup_years_path
    end

    private

    def build_resource(hash = {})
      invite_token = params[:invite_token].presence || params.dig(:user, :invite_token).presence
      cleaned_hash = hash.respond_to?(:except) ? hash.except(:invite_token) : hash
      super(cleaned_hash)
      resource.pending_invite_token = invite_token if resource.respond_to?(:pending_invite_token=)
      resource
    end

    def registration_layout
      %w[new create].include?(action_name) ? "devise" : "application"
    end
  end
end
