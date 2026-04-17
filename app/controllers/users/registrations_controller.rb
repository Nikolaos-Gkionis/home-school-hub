# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    layout :registration_layout

    protected

    def after_sign_up_path_for(resource)
      resource.reload
      send_welcome_email(resource)
      return child_dashboard_path if resource.learner?

      parent_dashboard_path
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

    def send_welcome_email(resource)
      if resource.learner?
        UserMailer.with(user: resource).welcome_child.deliver_now
      else
        UserMailer.with(user: resource).welcome_parent.deliver_now
      end
    rescue Net::SMTPAuthenticationError
      flash[:alert] = "Welcome email could not be sent because SMTP authentication failed."
    end
  end
end
