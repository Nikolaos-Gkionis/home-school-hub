# frozen_string_literal: true

Badge.find_or_create_by!(key: "daily_hero") do |b|
  b.name = "Daily Hero"
  b.description = "Completed 3 distinct lessons within 24 hours."
end

Badge.find_or_create_by!(key: "subject_master") do |b|
  b.name = "Subject Master"
  b.description = "Completed every lesson in a subject unit."
end

OakCurriculumSeed.call
Curriculum::YearBrowseSeeder.ensure_all!
Curriculum::MusicPracticeSeeder.ensure_all!
# Do not auto-import Oak here. After a reset, run:
#   bin/rails curriculum:oak_sync
# when you want the five hub subjects filled from Oak.
