# frozen_string_literal: true

module Child
  class ProfilesController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_child!

    def show
      @parent = current_user.parent
      @metrics = Insights::Summary.call(viewer: current_user, scope_user: current_user)
      @year_group_key = current_user.current_year_group_key
    end

    def update
      yk = params[:year_group_key].to_s
      unless Curriculum::YearGroups.all_year_keys.include?(yk)
        redirect_to child_profile_path, alert: "That school year is not available."
        return
      end

      current_user.move_to_year_group!(yk)
      redirect_to child_dashboard_path,
        notice: "You're now on #{Curriculum::YearGroups.label_for_year(yk)}."
    end
  end
end
