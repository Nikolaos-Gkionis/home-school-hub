# frozen_string_literal: true

class PagesController < ApplicationController
  layout "landing"

  skip_before_action :authenticate_user!, raise: false

  def home
    redirect_to role_home_path if user_signed_in?
  end
end
