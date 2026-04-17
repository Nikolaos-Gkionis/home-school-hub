# frozen_string_literal: true

class LegacyRedirectsController < ApplicationController
  before_action :authenticate_user!

  def dashboard
    redirect_to role_home_path
  end

  def insights
    redirect_to role_insights_path
  end
end
