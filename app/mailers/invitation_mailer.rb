# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  def invite
    @invitation = params[:invitation]
    mail(to: @invitation.email, subject: "You're invited to HomeSchool Hub")
  end
end
