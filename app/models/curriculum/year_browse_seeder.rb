# frozen_string_literal: true

module Curriculum
  # Removes legacy "browse Oak" / sign-in rows that are not single pupil-lesson slugs.
  class YearBrowseSeeder
    def self.ensure_all!
      YearGroups.all_year_keys.each { |yk| prune_year!(yk) }
    end

    def self.prune_year!(year_key)
      scope = Lesson.where(
        year_group_key: year_key,
        subject: Lesson::OAK_SUBJECT_NAME,
        unit: [ Lesson::OAK_BROWSE_UNIT, Lesson::OAK_ACCOUNT_UNIT ]
      )
      ids = scope.pluck(:id)
      return if ids.empty?

      User.where(last_active_lesson_id: ids).update_all(last_active_lesson_id: nil)
      User.where(last_completed_lesson_id: ids).update_all(last_completed_lesson_id: nil)
      scope.find_each(&:destroy!)
    end
  end
end
