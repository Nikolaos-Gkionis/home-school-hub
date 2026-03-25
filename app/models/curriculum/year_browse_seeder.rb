# frozen_string_literal: true

module Curriculum
  class YearBrowseSeeder
    def self.ensure_all!
      YearGroups.all_year_keys.each { |yk| ensure_year!(yk) }
    end

    def self.ensure_year!(year_key)
      unless Lesson.exists?(year_group_key: year_key, subject: Lesson::OAK_SUBJECT_NAME, unit: Lesson::OAK_BROWSE_UNIT)
        Lesson.create!(
          year_group_key: year_key,
          subject: Lesson::OAK_SUBJECT_NAME,
          unit: Lesson::OAK_BROWSE_UNIT,
          title: "Browse years & subjects (Oak)",
          external_url: "https://www.thenational.academy/pupils#hsh-#{year_key}",
          position: 1
        )
      end

      return if Lesson.exists?(year_group_key: year_key, subject: Lesson::OAK_SUBJECT_NAME, unit: Lesson::OAK_ACCOUNT_UNIT)

      Lesson.create!(
        year_group_key: year_key,
        subject: Lesson::OAK_SUBJECT_NAME,
        unit: Lesson::OAK_ACCOUNT_UNIT,
        title: "Sign in (library, downloads, some media)",
        external_url: "https://www.thenational.academy/sign-in#hsh-#{year_key}",
        position: 2
      )
    end
  end
end
