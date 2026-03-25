# frozen_string_literal: true

namespace :curriculum do
  desc "Idempotent seed of curriculum lessons"
  task seed: :environment do
    OakCurriculumSeed.call
    Curriculum::YearBrowseSeeder.ensure_all!
  end

  desc "Clear lessons and re-seed from YAML"
  task resync: :environment do
    Lesson.destroy_all
    OakCurriculumSeed.call
    Curriculum::YearBrowseSeeder.ensure_all!
  end
end
