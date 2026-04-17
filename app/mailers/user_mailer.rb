# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def welcome_parent
    @user = params[:user]
    @display_name = @user.email.to_s.split("@").first.tr(".", " ").titleize
    mail(to: @user.email, subject: "Welcome to HomeSchool Hub")
  end

  def welcome_child
    @user = params[:user]
    @parent = @user.parent
    @display_name = @user.learners.order(:position).first&.display_name.presence || @user.email.to_s.split("@").first.tr(".", " ").titleize
    mail(to: @user.email, subject: "Welcome to HomeSchool Hub")
  end
end
