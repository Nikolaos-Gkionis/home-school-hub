# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    layout :registration_layout

    protected

    def after_sign_up_path_for(_resource)
      onboarding_path
    end

    private

    def registration_layout
      %w[new create].include?(action_name) ? "devise" : "application"
    end
  end
end
