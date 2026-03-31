# frozen_string_literal: true

class AddOakTranscriptAndSyncedAtToLessons < ActiveRecord::Migration[8.1]
  SLUG_PATTERN = %r{thenational\.academy/pupils/lessons/([^/?#]+)}i

  def up
    add_column :lessons, :transcript_json, :json, null: false, default: {}
    add_column :lessons, :oak_synced_at, :datetime

    say_with_time "normalize legacy Oak lesson URLs to oak_hub" do
      Lesson.reset_column_information
      Lesson.find_each do |lesson|
        next if lesson.oak_lesson_slug.present?

        m = SLUG_PATTERN.match(lesson.external_url.to_s)
        next if m.blank?

        slug = m[1]
        Lesson.where(id: lesson.id).update_all(
          oak_lesson_slug: slug,
          content_mode: "oak_hub",
          external_url: "https://www.thenational.academy/pupils/lessons/#{slug}",
          updated_at: Time.current
        )
      end
    end
  end

  def down
    remove_column :lessons, :transcript_json
    remove_column :lessons, :oak_synced_at
  end
end
