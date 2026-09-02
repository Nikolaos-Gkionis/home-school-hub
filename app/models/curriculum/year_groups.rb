# frozen_string_literal: true

require "set"

module Curriculum
  class YearGroups
    PHASES = [
      { key: "eyfs", label: "Early years", years: [
        { key: "reception", label: "Reception" }
      ] },
      { key: "ks1", label: "Key Stage 1", years: [
        { key: "year_1", label: "Year 1" },
        { key: "year_2", label: "Year 2" }
      ] },
      { key: "ks2", label: "Key Stage 2", years: [
        { key: "year_3", label: "Year 3" },
        { key: "year_4", label: "Year 4" },
        { key: "year_5", label: "Year 5" },
        { key: "year_6", label: "Year 6" }
      ] },
      { key: "ks3", label: "Key Stage 3", years: [
        { key: "year_7", label: "Year 7" },
        { key: "year_8", label: "Year 8" },
        { key: "year_9", label: "Year 9" }
      ] },
      { key: "ks4", label: "Key Stage 4", years: [
        { key: "year_10", label: "Year 10" },
        { key: "year_11", label: "Year 11" }
      ] }
    ].freeze

    def self.all_year_keys
      @all_year_keys ||= PHASES.flat_map { |p| p[:years].map { |y| y[:key] } }.freeze
    end

    def self.phase_key_for_year(year_key)
      sk = year_key.to_s
      PHASES.find { |p| p[:years].any? { |y| y[:key] == sk } }&.fetch(:key)
    end

    def self.label_for_year(year_key)
      PHASES.each do |p|
        p[:years].each { |y| return y[:label] if y[:key] == year_key.to_s }
      end
      year_key.to_s.humanize
    end

    def self.select_options
      all_year_keys.map { |k| [ label_for_year(k), k ] }
    end

    def self.phases_for_years(year_keys)
      set = year_keys.map(&:to_s).to_set
      PHASES.select { |p| p[:years].any? { |y| set.include?(y[:key]) } }
    end
  end
end
