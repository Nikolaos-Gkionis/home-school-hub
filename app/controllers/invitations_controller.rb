# frozen_string_literal: true

class InvitationsController < ApplicationController
  before_action :authenticate_user!, except: [ :accept ]
  before_action :ensure_parent!, except: [ :accept ]

  def new
    @invitation = Invitation.new
  end

  def create
    @invitation = current_user.invitations.build(invitation_params)
    if @invitation.save
      InvitationMailer.with(invitation: @invitation).invite.deliver_later
      redirect_to new_invitation_path, notice: "Invitation sent to #{@invitation.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def accept
    inv = Invitation.find_by(token: params[:token])
    raise ActiveRecord::RecordNotFound if inv.blank? || inv.expired? || !inv.pending?

    redirect_to new_user_registration_path(user: { email: inv.email }, invite_token: inv.token)
  end

  private

  def ensure_parent!
    redirect_to dashboard_path, alert: "Only parent accounts can send invitations." unless current_user.parent?
  end

  def invitation_params
    params.require(:invitation).permit(:email, :year_group_key)
  end
end
