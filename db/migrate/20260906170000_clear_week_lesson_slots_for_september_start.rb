# frozen_string_literal: true

# September 2026 school weeks now start on Monday 7th, not 31 August.
# Saved drag-and-drop slots would keep the old layout, so wipe them and
# let the timetable pack again from the monthly unit plan.
class ClearWeekLessonSlotsForSeptemberStart < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM week_lesson_slots"
  end

  def down
    # Custom week layouts cannot be restored.
  end
end
