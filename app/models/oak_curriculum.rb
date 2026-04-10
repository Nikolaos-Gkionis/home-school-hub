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

    # Subjects shown in sidebar + setup checkboxes: full YAML list plus any extra names
    # present on synced lessons (so nothing in the hub is hidden from the filter).
    def hub_subject_filter_options
      yaml_names = display_names
      db_names = Lesson.distinct.order(:subject).pluck(:subject)
      return db_names if yaml_names.blank?

      (yaml_names + db_names).uniq.sort_by { |s| s.to_s.downcase }
    end
  end
end
