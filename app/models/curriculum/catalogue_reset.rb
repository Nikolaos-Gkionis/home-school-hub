# frozen_string_literal: true

module Curriculum
  # Wipes lessons and the rows that point at them, so the hub can start again
  # with only Maths, English, Science, History, and Music.
  #
  # Users, years, and logins stay. Practice lessons are put back afterwards.
  class CatalogueReset
    def self.call
      new.call
    end

    def call
      # Break FKs from users before deleting lessons.
      User.update_all(last_active_lesson_id: nil, last_completed_lesson_id: nil)

      WeekLessonSlot.delete_all
      LessonTimeLog.delete_all
      LessonQuizResponse.delete_all
      LessonSectionView.delete_all
      LessonCompletion.delete_all
      UnitMonthPlan.delete_all
      CheckpointTest.delete_all
      UserBadge.delete_all
      Lesson.delete_all

      # nil means "every remaining subject", which is now the five in YAML.
      Learner.update_all(preferred_subjects: nil)
      User.update_all(preferred_subjects: nil)

      MusicPracticeSeeder.ensure_all!
      YearBrowseSeeder.ensure_all!

      { lessons: Lesson.count }
    end
  end
end
