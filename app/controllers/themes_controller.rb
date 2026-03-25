# frozen_string_literal: true

class ThemesController < ApplicationController
  before_action :authenticate_user!

  def update
    if ThemeManager::PRESETS.key?(params.dig(:user, :current_theme))
      current_user.update!(current_theme: params[:user][:current_theme])
    end
    redirect_back fallback_location: root_path
  end
end
