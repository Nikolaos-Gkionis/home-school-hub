# frozen_string_literal: true

require "yaml"

# Reads config/oak_curriculum.yml for subject labels used in setup and filters.
class OakCurriculum
  CONFIG_PATH = Rails.root.join("config/oak_curriculum.yml")

  class << self
    def subject_rows
      return [] unless CONFIG_PATH.exist?

      rows = YAML.load_file(CONFIG_PATH)["subjects"]
      Array(rows)
    end

    def display_names
      subject_rows.filter_map { |r| r["display_name"].presence || r["slug"]&.titleize }
    end
  end
end
