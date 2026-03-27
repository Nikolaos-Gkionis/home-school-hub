# frozen_string_literal: true

module Oak
  # Maps app year_group_key (e.g. year_7) to Oak API key-stage slugs.
  module KeyStageForYear
    module_function

    def call(year_group_key)
      y = year_group_key.to_s.delete_prefix("year_").to_i
      return "ks3" if (7..9).cover?(y)
      return "ks4" if (10..11).cover?(y)

      return "ks2" if (3..6).cover?(y)
      return "ks1" if (1..2).cover?(y)

      "ks1"
    end

    def year_slug(year_group_key)
      k = year_group_key.to_s
      return "reception" if k == "reception"

      "year-#{k.delete_prefix("year_")}"
    end
  end
end
