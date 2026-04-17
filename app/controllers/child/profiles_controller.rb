# frozen_string_literal: true

module Child
  class ProfilesController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_child!

    def show
      @parent = current_user.parent
      @metrics = Insights::Summary.call(viewer: current_user, scope_user: current_user)
    end
  end
end
