# frozen_string_literal: true

require "test_helper"

class LessonOrderingTest < ActiveSupport::TestCase
  test "ordered scope sorts by unit_position before unit name" do
    later = Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: "Zebra unit",
      unit_position: 2,
      title: "Later unit lesson",
      external_url: "https://www.thenational.academy/pupils/lessons/order-test-zebra",
      oak_lesson_slug: "order-test-zebra",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
    earlier = Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: "Apple unit",
      unit_position: 1,
      title: "Earlier unit lesson",
      external_url: "https://www.thenational.academy/pupils/lessons/order-test-apple",
      oak_lesson_slug: "order-test-apple",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )

    ids = Lesson.where(id: [ earlier.id, later.id ]).ordered.pluck(:id)
    assert_equal [ earlier.id, later.id ], ids
  end
end
