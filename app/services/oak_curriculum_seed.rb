# frozen_string_literal: true

require "yaml"

class OakCurriculumSeed
  PATH = Rails.root.join("config/curriculum/oak_year7.yml")
  PUPIL_LESSON_SLUG_PATTERN = %r{thenational\.academy/pupils/lessons/([^/?#]+)}i

  def self.call
    new.call
  end

  def call
    return unless PATH.exist?

    rows = YAML.load_file(PATH)
    rows = rows["lessons"] if rows.is_a?(Hash)
    Array(rows).each do |row|
      attrs = row.stringify_keys
      url = attrs["external_url"]
      next if url.blank?

      year = attrs["year_group"].presence || "year_7"

      lesson = Lesson.find_or_initialize_by(
        year_group_key: year,
        subject: attrs["subject"],
        unit: attrs["unit"],
        title: attrs["title"]
      )
      lesson.assign_attributes(
        external_url: url,
        position: attrs["position"].to_i
      )
      if (slug = extract_pupil_lesson_slug(url))
        lesson.oak_lesson_slug = slug
        lesson.content_mode = Lesson::CONTENT_MODE_OAK_HUB
        lesson.external_url = "https://www.thenational.academy/pupils/lessons/#{slug}"
      end
      lesson.save!
    end
  end

  def extract_pupil_lesson_slug(url)
    PUPIL_LESSON_SLUG_PATTERN.match(url.to_s)&.captures&.first
  end
end
