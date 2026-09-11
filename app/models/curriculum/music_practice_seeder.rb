# frozen_string_literal: true

module Curriculum
  # One in-app instrument-practice lesson per year group (not an Oak page).
  class MusicPracticeSeeder
    def self.ensure_all!
      YearGroups.all_year_keys.filter_map { |year_key| ensure_for_year!(year_key) }
    end

    def self.ensure_for_year!(year_key)
      return if year_key.blank?

      Lesson.create_with(
        title: Lesson::PRACTICE_TITLE,
        external_url: Lesson::PRACTICE_PLACEHOLDER_URL,
        oak_lesson_slug: nil,
        position: 1,
        unit_position: 1
      ).find_or_create_by!(
        year_group_key: year_key.to_s,
        subject: Lesson::MUSIC_SUBJECT_NAME,
        unit: Lesson::PRACTICE_UNIT,
        content_mode: Lesson::CONTENT_MODE_PRACTICE
      )
    end
  end
end
