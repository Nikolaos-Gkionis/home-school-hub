# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    layout :registration_layout

    protected

    def after_sign_up_path_for(resource)
      resource.reload
      return dashboard_path if resource.learner?

      setup_years_path
    end

    private

    def build_resource(hash = {})
      super(hash)
      resource.pending_invite_token = params.dig(:user, :invite_token) if resource.respond_to?(:pending_invite_token=)
      resource
    end

    def registration_layout
      %w[new create].include?(action_name) ? "devise" : "application"
    end
  end
end
