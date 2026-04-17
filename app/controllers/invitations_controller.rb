# frozen_string_literal: true

class InvitationsController < ApplicationController
  include RoleAccess

  before_action :authenticate_user!, except: [ :accept ]
  before_action :require_parent!, except: [ :accept ]

  def new
    @invitation = Invitation.new
  end

  def create
    @invitation = current_user.invitations.build(invitation_params)
    if @invitation.save
      if send_invitation_email(@invitation)
        redirect_to new_invitation_path, notice: invite_delivery_notice(@invitation.email)
      else
        redirect_to new_invitation_path, alert: smtp_auth_error_message
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def resend
    invitation = current_user.invitations.find(params[:id])
    if invitation.accepted_at.present?
      redirect_back fallback_location: parent_family_path, alert: "That invite is already accepted."
      return
    end
    if invitation.expired?
      redirect_back fallback_location: parent_family_path, alert: "That invite has expired. Create a new invite."
      return
    end

    if send_invitation_email(invitation)
      redirect_back fallback_location: parent_family_path, notice: invite_delivery_notice(invitation.email)
    else
      redirect_back fallback_location: parent_family_path, alert: smtp_auth_error_message
    end
  end

  def accept
    inv = Invitation.find_by(token: params[:token])
    raise ActiveRecord::RecordNotFound if inv.blank? || inv.expired? || !inv.pending?

    redirect_to new_user_registration_path(user: { email: inv.email }, invite_token: inv.token)
  end

  private

  def invitation_params
    params.require(:invitation).permit(:child_name, :email, :year_group_key)
  end

  def send_invitation_email(invitation)
    delivery = Rails.env.production? ? :deliver_later : :deliver_now
    InvitationMailer.with(invitation: invitation).invite.public_send(delivery)
    true
  rescue Net::SMTPAuthenticationError
    false
  end

  def invite_delivery_notice(email)
    notice = "Invitation sent to #{email}."
    if Rails.env.development? && ENV["SMTP_ADDRESS"].blank?
      notice += " SMTP is not configured, so this message was written to tmp/mails."
    end
    notice
  end

  def smtp_auth_error_message
    "SMTP authentication failed. Check SMTP_USERNAME and SMTP_PASSWORD in .env (use a Gmail App Password, not your normal Gmail password), then restart the server."
  end
end
