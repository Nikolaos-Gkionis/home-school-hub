# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Dir[Rails.root.join("test/support/**/*.rb")].sort.each { |f| require f }

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    # Add more helper methods to be used by all tests here...
  end
end
