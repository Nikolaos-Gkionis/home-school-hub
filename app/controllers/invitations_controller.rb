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
        redirect_to new_invitation_path, alert: invitation_email_error_message
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @invitation = current_user.invitations.find(params[:id])
  end

  def update
    @invitation = current_user.invitations.find(params[:id])
    if @invitation.accepted_at.present?
      redirect_to parent_family_path, alert: "Accepted invites cannot be edited."
      return
    end

    if @invitation.update(invitation_params)
      redirect_to parent_family_path, notice: "Invite updated for #{@invitation.email}."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    invitation = current_user.invitations.find(params[:id])
    email = invitation.email
    invitation.destroy!
    redirect_back fallback_location: parent_family_path, notice: "Deleted invite for #{email}."
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
      redirect_back fallback_location: parent_family_path, alert: invitation_email_error_message
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

  # Use deliver_now so SMTP/template errors surface here (and are rescued) instead of failing Solid Queue enqueue/work.
  def send_invitation_email(invitation)
    @invitation_mailer_error_class = nil
    InvitationMailer.with(invitation: invitation).invite.deliver_now
    true
  rescue Net::SMTPAuthenticationError => e
    @invitation_mailer_error_class = e.class.name
    Rails.logger.warn("Invitation SMTP auth failed: #{e.message}")
    false
  rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError => e
    @invitation_mailer_error_class = e.class.name
    Rails.logger.warn("Invitation SMTP connection failed (#{e.class}): #{e.message}")
    false
  rescue StandardError => e
    @invitation_mailer_error_class = e.class.name
    Rails.logger.error("Invitation email failed (#{e.class}): #{e.message}\n#{e.backtrace&.first(12)&.join("\n")}")
    false
  end

  def invite_delivery_notice(email)
    notice = "Invitation sent to #{email}."
    if Rails.env.development? && ENV["SMTP_ADDRESS"].blank?
      notice += " SMTP is not configured, so this message was written to tmp/mails."
    end
    notice
  end

  def invitation_email_error_message
    base = "We could not send the invitation email. Confirm MAILER_FROM uses your Gmail address " \
      "(same as SMTP_USERNAME), and SMTP_PASSWORD is a Google App Password. Redeploy after changing secrets. " \
      "Server logs include the full error."
    @invitation_mailer_error_class.present? ? "#{base} (#{@invitation_mailer_error_class})" : base
  end
end
