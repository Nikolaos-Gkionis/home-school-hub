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

    def initialize(limit_per_subject: nil, year_groups: nil, hydrate: nil)
      raw = limit_per_subject || ENV["OAK_IMPORT_LIMIT"].presence&.to_i
      # Treat 0 as unset so a mistaken OAK_IMPORT_LIMIT=0 does not skip all lessons.
      @limit_per_subject = raw&.nonzero?&.to_i
      @year_groups = Array(year_groups).map(&:to_s).reject(&:blank?)
      @hydrate = hydrate.nil? ? ENV["OAK_SKIP_POST_IMPORT_HYDRATE"] != "1" : hydrate
    end

    def call
      unless ApiClient.configured?
        Rails.logger.info("[Oak::Importer] Skipped: set OAK_API_TOKEN (see README).")
        return { created: 0, updated: 0, skipped: true, hydrated: 0 }
      end

      created = 0
      updated = 0
      cfg = load_config
      year_groups = years_to_import(Array(cfg["year_groups"]))
      subjects = Array(cfg["subjects"])
      created = 0
      updated = 0

      if year_groups.empty?
        Rails.logger.warn("[Oak::Importer] No year groups to import (check config/oak_curriculum.yml or OAK_SYNC_YEARS).")
        return { created: 0, updated: 0, skipped: true, hydrated: 0 }
      end

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

      hydrated = 0
      if @hydrate
        r = PostImportHydrator.call
        hydrated = r[:hydrated].to_i
      end

      { created:, updated:, skipped: false, hydrated: }
    rescue ApiClient::RateLimited => e
      Rails.logger.error("[Oak::Importer] Stopped: #{e.message}")
      { created:, updated:, hydrated: 0, error: e.message, rate_limited: true }
    rescue ApiClient::Unauthorized => e
      Rails.logger.error("[Oak::Importer] #{e.message}")
      { created: 0, updated: 0, hydrated: 0, error: e.message }
    end

    private

    def load_config
      raise "Missing #{CONFIG_PATH}" unless CONFIG_PATH.exist?

      YAML.load_file(CONFIG_PATH)
    end

    # OAK_SYNC_YEARS=year_8 (comma or space separated) imports only those years.
    def years_to_import(configured)
      keys = configured.map(&:to_s)
      wanted = @year_groups.presence || ENV["OAK_SYNC_YEARS"].to_s.split(/[\s,]+/).map(&:strip).reject(&:blank?)
      return keys if wanted.blank?

      keys & wanted
    end

    def import_subject_year!(year_key:, year_slug:, key_stage:, subject_slug:, display_name:)
      @lesson_meta_cache = {}
      @lesson_meta_cache_updated = false
      created = 0
      updated = 0
      ordered_units = SequenceUnitList.call(year_group_key: year_key, subject_slug: subject_slug)
      if ordered_units.blank?
        begin
          path = "/key-stages/#{key_stage}/subject/#{subject_slug}/units"
          units_response = ApiClient.get_json(path)
          block = Array(units_response).find { |b| b["yearSlug"].to_s == year_slug }
          if block.blank?
            Rails.logger.warn("[Oak::Importer] No units for #{subject_slug} #{year_slug} (check slug / year).")
            return { created: 0, updated: 0 }
          end

          ordered_units = Array(block["units"]).map.with_index do |u, i|
            {
              "unitSlug" => u["unitSlug"].to_s,
              "unitTitle" => u["unitTitle"].to_s,
              "unitOrder" => i + 1
            }
          end
        rescue ApiClient::RateLimited
          raise
        rescue ApiClient::BadResponse => e
          Rails.logger.warn("[Oak::Importer] #{subject_slug} @ #{year_key} key-stages list: #{e.message}")
          return { created: 0, updated: 0 }
        end
      end

      per_subj = 0
      ordered_units.each do |unit|
        break if @limit_per_subject && per_subj >= @limit_per_subject

        unit_slug = unit["unitSlug"].to_s
        unit_title = unit["unitTitle"].to_s
        unit_position = unit["unitOrder"].to_i
        next if unit_slug.blank?

        unit_summary =
          begin
            ApiClient.get_json("/units/#{unit_slug}/summary")
          rescue ApiClient::RateLimited
            raise
          rescue ApiClient::BadResponse => e
            if copyright_blocked_error?(e)
              Rails.logger.info("[Oak::Importer] #{subject_slug} @ #{year_key} unit #{unit_slug}: unit summary unavailable (copyright); using sequence assets + per-lesson summaries.")
              warm_lesson_unit_meta!(subject_slug:, year_key:)
              delta = import_unit_via_assets_fallback!(
                year_key:, subject_slug:, key_stage:, display_name:,
                unit_slug:, unit_title:, unit_position:, per_subj:
              )
              created += delta[:created]
              updated += delta[:updated]
              per_subj += delta[:imported]
              nil
            else
              Rails.logger.warn("[Oak::Importer] #{subject_slug} @ #{year_key} unit #{unit_slug}: #{e.message}")
              nil
            end
          end

        next if unit_summary.blank?

        Array(unit_summary["unitLessons"]).each do |ul|
          break if @limit_per_subject && per_subj >= @limit_per_subject

          next if ul["state"].to_s != "published"

          lesson_slug = ul["lessonSlug"]
          lesson_title = ul["lessonTitle"]
          position = ul["lessonOrder"].to_i

          r = persist_oak_hub_lesson!(
            year_key:, lesson_slug:, lesson_title:, position:,
            unit_title:, unit_position:, key_stage:, subject_slug:, display_name:
          )
          per_subj += 1
          if r[:was_new]
            created += 1
          else
            updated += 1
          end
        end
      end

      { created:, updated: }
    end

    def copyright_blocked_error?(error)
      msg = error.message.to_s.downcase
      msg.match?(/copyright|blocked/)
    end

    def sequence_asset_rows(subject_slug, year_key)
      y = SequenceUnitList.year_query_number(year_key)
      return [] if y.nil?

      phase = SequenceUnitList.sequence_phase(year_key)
      Array(ApiClient.get_json("/sequences/#{subject_slug}-#{phase}/assets?year=#{y}"))
    rescue ApiClient::RateLimited
      raise
    rescue ApiClient::BadResponse => e
      Rails.logger.warn("[Oak::Importer] sequence assets #{subject_slug} @ #{year_key}: #{e.message}")
      []
    end

    def warm_lesson_unit_meta!(subject_slug:, year_key:)
      return if @lesson_meta_cache_updated

      sequence_asset_rows(subject_slug, year_key).each do |row|
        slug = row["lessonSlug"].to_s
        next if slug.blank?

        lesson_unit_meta_for_slug(slug)
      end
      @lesson_meta_cache_updated = true
    end

    def lesson_unit_meta_for_slug(slug)
      return @lesson_meta_cache[slug] if @lesson_meta_cache.key?(slug)

      summary = ApiClient.get_json("/lessons/#{slug}/summary")
      @lesson_meta_cache[slug] = {
        unit_slug: summary["unitSlug"].to_s,
        title: summary["lessonTitle"].to_s
      }
    rescue ApiClient::RateLimited
      raise
    rescue ApiClient::BadResponse
      @lesson_meta_cache[slug] = nil
    end

    def import_unit_via_assets_fallback!(year_key:, subject_slug:, key_stage:, display_name:, unit_slug:, unit_title:, unit_position:, per_subj:)
      created = 0
      updated = 0
      imported = 0
      position = 0

      sequence_asset_rows(subject_slug, year_key).each do |row|
        break if @limit_per_subject && (per_subj + imported) >= @limit_per_subject

        slug = row["lessonSlug"].to_s
        next if slug.blank?

        meta = lesson_unit_meta_for_slug(slug)
        next unless meta && meta[:unit_slug] == unit_slug

        position += 1
        r = persist_oak_hub_lesson!(
          year_key:, lesson_slug: slug, lesson_title: meta[:title].presence || row["lessonTitle"].to_s,
          position:,
          unit_title:, unit_position:, key_stage:, subject_slug:, display_name:
        )
        imported += 1
        if r[:was_new]
          created += 1
        else
          updated += 1
        end
      end

      if imported.zero?
        Rails.logger.warn("[Oak::Importer] #{subject_slug} unit #{unit_slug}: copyright fallback imported 0 lessons (check API / sequence assets).")
      end

      { created:, updated:, imported: }
    end

    def persist_oak_hub_lesson!(year_key:, lesson_slug:, lesson_title:, position:, unit_title:, unit_position:, key_stage:, subject_slug:, display_name:)
      lesson = Lesson.find_or_initialize_by(
        year_group_key: year_key,
        oak_lesson_slug: lesson_slug
      )
      was_new = lesson.new_record?
      lesson.assign_attributes(
        title: lesson_title,
        unit: unit_title,
        unit_position: unit_position,
        subject: display_name,
        oak_subject_slug: subject_slug,
        oak_key_stage_slug: key_stage,
        content_mode: Lesson::CONTENT_MODE_OAK_HUB,
        position: position,
        external_url: "https://www.thenational.academy/pupils/lessons/#{lesson_slug}",
        summary_json: {},
        assets_json: {},
        quizzes_json: {},
        transcript_json: {}
      )
      lesson.save!
      { was_new: was_new }
    end
  end
end
