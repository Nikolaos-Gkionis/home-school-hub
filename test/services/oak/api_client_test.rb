# frozen_string_literal: true

require "test_helper"

module Oak
  class ApiClientTest < ActiveSupport::TestCase
    setup do
      ApiClient.cooldown_until = nil
    end

    teardown do
      ApiClient.cooldown_until = nil
    end

    test "parse_retry_after reads integer seconds" do
      assert_equal 45, ApiClient.parse_retry_after("45")
    end

    test "parse_retry_after returns nil for blank" do
      assert_nil ApiClient.parse_retry_after(nil)
      assert_nil ApiClient.parse_retry_after("")
    end

    test "cooldown raises immediately without hitting the network" do
      ApiClient.cooldown_until = Time.now + 60
      error = assert_raises(ApiClient::RateLimited) { ApiClient.get_json("/lessons/anything/summary") }
      assert_match(/cooling down/, error.message)
    end
  end

  class ImporterYearFilterTest < ActiveSupport::TestCase
    setup do
      @years_was = ENV["OAK_SYNC_YEARS"]
    end

    teardown do
      if @years_was.nil?
        ENV.delete("OAK_SYNC_YEARS")
      else
        ENV["OAK_SYNC_YEARS"] = @years_was
      end
    end

    test "years_to_import keeps config years when env is blank" do
      ENV["OAK_SYNC_YEARS"] = nil
      importer = Importer.new
      assert_equal %w[year_7 year_8], importer.send(:years_to_import, %w[year_7 year_8])
    end

    test "years_to_import can limit to year 8" do
      ENV["OAK_SYNC_YEARS"] = "year_8"
      importer = Importer.new
      assert_equal %w[year_8], importer.send(:years_to_import, %w[year_7 year_8])
    end

    test "constructor year_groups argument wins over env" do
      ENV["OAK_SYNC_YEARS"] = "year_7"
      importer = Importer.new(year_groups: [ "year_8" ])
      assert_equal %w[year_8], importer.send(:years_to_import, %w[year_7 year_8])
    end
  end
end
