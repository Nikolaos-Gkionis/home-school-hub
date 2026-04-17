# frozen_string_literal: true

module Child
  class DashboardsController < DashboardController
    include RoleAccess

    before_action :require_child!
  end
end
