# frozen_string_literal: true

# One teaching slot on a child's weekly calendar.
# Breaks and lunch are never stored here — those stay fixed on the clock.
class WeekLessonSlot < ApplicationRecord
  belongs_to :user
  belongs_to :lesson, optional: true

  validates :slot_date, :period_key, presence: true
  validates :period_key, inclusion: { in: %w[p1 p2 p3 p4 p5] }
  validates :period_key, uniqueness: { scope: [ :user_id, :slot_date ] }
end
