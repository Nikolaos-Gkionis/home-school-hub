# frozen_string_literal: true

module Oak
  # Loads units in Oak's **published sequence order** via
  # GET /sequences/{subject}-{primary|secondary}/units?year=N
  #
  # The key-stages unit listing returns the same slugs but in an arbitrary order,
  # which does not match the pupil site or pedagogy.
  module SequenceUnitList
    module_function

    # @return [Array<Hash>, nil] each element has string keys unitSlug, unitTitle, unitOrder; or nil if unavailable
    def call(year_group_key:, subject_slug:)
      year = year_query_number(year_group_key)
      return nil if year.nil?

      phase = sequence_phase(year_group_key)
      path = "/sequences/#{subject_slug}-#{phase}/units?year=#{year}"
      data = ApiClient.get_json(path)
      block = Array(data).find { |b| b["year"].to_i == year } || Array(data).first
      return nil unless block.is_a?(Hash)

      normalize_units_from_block(block)
    rescue ApiClient::RateLimited
      raise
    rescue ApiClient::BadResponse => e
      Rails.logger.warn("[Oak::SequenceUnitList] #{subject_slug} year #{year}: #{e.message}")
      nil
    end

    def year_query_number(year_group_key)
      k = year_group_key.to_s
      return nil if k == "reception"

      m = /\Ayear_(\d+)\z/.match(k)
      m ? m[1].to_i : nil
    end

    def sequence_phase(year_group_key)
      ks = KeyStageForYear.call(year_group_key)
      %w[ks3 ks4].include?(ks) ? "secondary" : "primary"
    end

    def normalize_units_from_block(block)
      units = Array(block["units"])
      return units.map { |u| normalize_unit_hash(u) } if units.any?

      flat = []
      Array(block["examSubjects"]).each do |exam_subject|
        Array(exam_subject["tiers"]).each do |tier|
          Array(tier["units"]).each { |u| flat << normalize_unit_hash(u) }
        end
      end

      return [] if flat.empty?

      # KS4 science (etc.): tiers repeat unitOrder from 1; use traversal order for stable hub ordering
      flat.each_with_index.map do |u, i|
        u.merge("unitOrder" => i + 1)
      end
    end

    def normalize_unit_hash(u)
      {
        "unitSlug" => u["unitSlug"].to_s,
        "unitTitle" => u["unitTitle"].to_s,
        "unitOrder" => u["unitOrder"].to_i
      }
    end
  end
end
