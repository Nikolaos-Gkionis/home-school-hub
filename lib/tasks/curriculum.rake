# frozen_string_literal: true

namespace :curriculum do
  desc "Idempotent seed of curriculum lessons (no Oak import)"
  task seed: :environment do
    OakCurriculumSeed.call
    Curriculum::YearBrowseSeeder.ensure_all!
    Curriculum::MusicPracticeSeeder.ensure_all!
  end

  desc "Sync published Oak lessons from the Open API (requires OAK_API_TOKEN).
        Optional: OAK_SYNC_YEARS=year_8 OAK_SKIP_POST_IMPORT_HYDRATE=1"
  task oak_sync: :environment do
    Oak::ApiClient.cooldown_until = nil
    result = Oak::Importer.call
    puts result.inspect
    if result.is_a?(Hash) && result[:rate_limited]
      puts "Stopped because Oak is rate-limiting. Wait 30-60 minutes, then retry with:"
      puts "  OAK_SYNC_YEARS=year_8 OAK_SKIP_POST_IMPORT_HYDRATE=1 bin/rails curriculum:oak_sync"
    elsif result.is_a?(Hash) && result[:hydrated].to_i.positive?
      puts "Post-import hydration: #{result[:hydrated]} lesson(s) fetched summary/assets/quiz/transcript."
    end
  end

  desc "Wipe lessons, year plans, and progress so you can set subjects up again.
        Keeps users. Puts Music practice rows back. Does not call Oak."
  task reset_lessons: :environment do
    result = Curriculum::CatalogueReset.call
    puts "Lessons remaining (practice rows): #{result[:lessons]}"
  end

  desc "Wipe lessons then seed YAML practice rows (no Oak import)"
  task resync: :environment do
    Curriculum::CatalogueReset.call
    OakCurriculumSeed.call
  end
end
