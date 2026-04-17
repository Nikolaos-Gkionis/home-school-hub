# frozen_string_literal: true

class UserMailer < ApplicationMailer
  def welcome_parent
    @user = params[:user]
    mail(to: @user.email, subject: "Welcome to HomeSchool Hub")
  end

  def welcome_child
    @user = params[:user]
    @parent = @user.parent
    mail(to: @user.email, subject: "Welcome to HomeSchool Hub")
  end
end
