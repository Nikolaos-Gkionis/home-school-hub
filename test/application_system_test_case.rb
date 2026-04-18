# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Headless Chrome + axe in one process: keep one worker to reduce flakiness.
  parallelize(workers: 1)

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  # WCAG 2.1 AA includes color contrast; axe also covers many ARIA/name rules.
  accessibility_audit_options.according_to = :wcag21aa

  include SystemTestUsers
end
