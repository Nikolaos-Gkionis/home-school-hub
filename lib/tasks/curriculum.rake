# frozen_string_literal: true

namespace :curriculum do
  desc "Idempotent seed of curriculum lessons"
  task seed: :environment do
    OakCurriculumSeed.call
    Curriculum::YearBrowseSeeder.ensure_all!
    Oak::Importer.call if Oak::ApiClient.configured?
  end

  desc "Sync published Oak lessons from the Open API (requires OAK_API_TOKEN)"
  task oak_sync: :environment do
    result = Oak::Importer.call
    puts result.inspect
  end

  desc "Clear lessons and re-seed from YAML"
  task resync: :environment do
    Lesson.destroy_all
    OakCurriculumSeed.call
    Curriculum::YearBrowseSeeder.ensure_all!
    Oak::Importer.call if Oak::ApiClient.configured?
  end
end
