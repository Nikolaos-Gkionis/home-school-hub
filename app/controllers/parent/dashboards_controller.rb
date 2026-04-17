# frozen_string_literal: true

module Parent
  class DashboardsController < DashboardController
    include RoleAccess

    before_action :require_parent!
  end
end
