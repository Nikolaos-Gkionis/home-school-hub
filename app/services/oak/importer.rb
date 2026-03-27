# frozen_string_literal: true

require "yaml"

module Oak
  # Idempotent import of published lessons from the Oak Open API into +Lesson+ rows.
  class Importer
    CONFIG_PATH = Rails.root.join("config/oak_curriculum.yml")

    class << self
      def call(**kwargs)
        new(**kwargs).call
      end
    end

    def initialize(limit_per_subject: nil)
      @limit_per_subject = (limit_per_subject || ENV["OAK_IMPORT_LIMIT"].presence&.to_i)
    end

    def call
      unless ApiClient.configured?
        Rails.logger.info("[Oak::Importer] Skipped: set OAK_API_TOKEN (see README).")
        return { created: 0, updated: 0, skipped: true }
      end

      cfg = load_config
      year_groups = Array(cfg["year_groups"])
      subjects = Array(cfg["subjects"])
      created = 0
      updated = 0

      year_groups.each do |year_key|
        ks = KeyStageForYear.call(year_key)
        year_slug = KeyStageForYear.year_slug(year_key)

        subjects.each do |subj|
          slug = subj["slug"].to_s
          display = subj["display_name"].presence || slug.tr("-", " ").titleize
          n = import_subject_year!(year_key:, year_slug:, key_stage: ks, subject_slug: slug, display_name: display)
          created += n[:created]
          updated += n[:updated]
        end
      end

      { created:, updated:, skipped: false }
    rescue ApiClient::Unauthorized => e
      Rails.logger.error("[Oak::Importer] #{e.message}")
      { created: 0, updated: 0, error: e.message }
    end

    private

    def load_config
      raise "Missing #{CONFIG_PATH}" unless CONFIG_PATH.exist?

      YAML.load_file(CONFIG_PATH)
    end

    def import_subject_year!(year_key:, year_slug:, key_stage:, subject_slug:, display_name:)
      created = 0
      updated = 0
      path = "/key-stages/#{key_stage}/subject/#{subject_slug}/units"
      units_response = ApiClient.get_json(path)
      block = Array(units_response).find { |b| b["yearSlug"].to_s == year_slug }
      if block.blank?
        Rails.logger.warn("[Oak::Importer] No units for #{subject_slug} #{year_slug} (check slug / year).")
        return { created: 0, updated: 0 }
      end

      per_subj = 0
      Array(block["units"]).each do |unit|
        break if @limit_per_subject && per_subj >= @limit_per_subject

        unit_slug = unit["unitSlug"]
        unit_title = unit["unitTitle"]

        unit_summary = ApiClient.get_json("/units/#{unit_slug}/summary")
        Array(unit_summary["unitLessons"]).each do |ul|
          break if @limit_per_subject && per_subj >= @limit_per_subject

          next if ul["state"].to_s != "published"

          lesson_slug = ul["lessonSlug"]
          lesson_title = ul["lessonTitle"]
          position = ul["lessonOrder"].to_i

          lesson = Lesson.find_or_initialize_by(
            year_group_key: year_key,
            oak_lesson_slug: lesson_slug
          )
          was_new = lesson.new_record?
          lesson.assign_attributes(
            title: lesson_title,
            unit: unit_title,
            subject: display_name,
            oak_subject_slug: subject_slug,
            oak_key_stage_slug: key_stage,
            content_mode: Lesson::CONTENT_MODE_OAK_HUB,
            position: position,
            external_url: "https://www.thenational.academy/pupils/lessons/#{lesson_slug}",
            summary_json: {},
            assets_json: {},
            quizzes_json: {}
          )
          lesson.save!
          per_subj += 1
          if was_new
            created += 1
          else
            updated += 1
          end
        end
      end

      { created:, updated: }
    rescue ApiClient::BadResponse => e
      Rails.logger.warn("[Oak::Importer] #{subject_slug} @ #{year_key}: #{e.message}")
      { created: 0, updated: 0 }
    end
  end
end
