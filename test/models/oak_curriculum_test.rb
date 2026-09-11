# frozen_string_literal: true

require "test_helper"

class OakCurriculumTest < ActiveSupport::TestCase
  test "hub subjects are the five we teach" do
    assert_equal(
      [ "English", "History", "Mathematics", "Music", "Science" ],
      OakCurriculum.hub_subject_filter_options
    )
  end
end
