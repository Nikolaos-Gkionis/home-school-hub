# frozen_string_literal: true

module Curriculum
  # Builds one school day's 5-hour timetable in memory (no slot table).
  # Hours 1–3: core Oak. Hour 4: Music theory. Hour 5: instrument practice.
  # The clock (breaks, lunch, 09:00–15:15) lives on TimetableClock so Day and
  # Week can paint the same bell times without changing which lesson is in hour 2.
  #
  # Weekdays share one ordered pool: Monday uses the first 3 core lessons,
  # Tuesday the next 3, and so on. That way Day and Week show the same plan.
  class SchoolDay
    CORE_HOURS = 3
    SCHOOL_DAYS = 5

    Slot = Struct.new(:hour, :kind, :label, :period, :lesson, :key, :starts_at, :ends_at, keyword_init: true) do
      def break?
        kind == :break
      end

      def lunch?
        kind == :lunch
      end

      def teaching?
        !break? && !lunch?
      end

      def clock_range
        return period if starts_at.blank? || ends_at.blank?

        "#{starts_at}–#{ends_at}"
      end
    end

    def self.call(user, date = Date.current)
      new(user: user, date: date)
    end

    def initialize(user:, date: Date.current)
      @user = user
      @date = date
    end

    attr_reader :date

    def slots
      @slots ||= [
        teaching_slot(0, :core, "Hour 1", "Morning", core_lessons[0]),
        teaching_slot(1, :core, "Hour 2", "Morning", core_lessons[1]),
        teaching_slot(2, :core, "Hour 3", "Morning", core_lessons[2]),
        teaching_slot(3, :music_theory, "Music theory", "Afternoon", music_theory_lesson),
        teaching_slot(4, :music_practice, "Music practice", "Afternoon", music_practice_lesson)
      ]
    end

    # Lessons plus comfort breaks and lunch, in clock order (09:00–15:15).
    def timeline
      @timeline ||= TimetableClock::PERIODS.map do |clock|
        next slots[TimetableClock.teaching_index(clock.key)] if clock.lesson?

        Slot.new(
          hour: nil,
          kind: clock.kind,
          label: clock.label,
          period: clock.kind.to_s.titleize,
          lesson: nil,
          key: clock.key,
          starts_at: clock.starts_at,
          ends_at: clock.ends_at
        )
      end
    end

    def morning_slots
      slots.first(CORE_HOURS)
    end

    def afternoon_slots
      slots.last(2)
    end

    # Monday = 0 … Friday = 4. Saturday/Sunday have no school day.
    def weekday_index
      return if weekend?

      @date.cwday - 1
    end

    def weekend?
      @date.saturday? || @date.sunday?
    end

    # Monday–Friday inside September → third week of July.
    def in_term?
      AcademicYear.school_date?(@date)
    end

    # Weekday that is still a calendar school month, but after term has ended
    # (late July / August) or before September starts.
    def holiday?
      !weekend? && !in_term?
    end

    def today?
      @date == Date.current
    end

    def weekday_name
      @date.strftime("%A")
    end

    def short_weekday
      @date.strftime("%a")
    end

    def day_label
      @date.strftime("%-d %b")
    end

    private

    def teaching_slot(index, kind, label, period, lesson)
      clock = TimetableClock::TEACHING_PERIODS.fetch(index)
      Slot.new(
        hour: index + 1,
        kind: kind,
        label: label,
        period: period,
        lesson: lesson,
        key: clock.key,
        starts_at: clock.starts_at,
        ends_at: clock.ends_at
      )
    end

    def year_key
      @year_key ||= @user.current_year_group_key
    end

    def core_lessons
      @core_lessons ||= pick_round_robin(core_candidates, CORE_HOURS, offset: core_offset)
    end

    def core_offset
      (weekday_index || 0) * CORE_HOURS
    end

    def core_candidates
      return [] if year_key.blank?

      lessons = if @user.pacing_active?(year_group_key: year_key, academic_year: academic_year)
        lessons_from_this_month_core_units
      else
        # No year plan yet: still rotate through visible non-music work.
        @user.visible_lessons_relation.core_curriculum.where(year_group_key: year_key).ordered.to_a
      end

      lessons.select { |lesson| preferred_core_subject?(lesson.subject) }
    end

    def lessons_from_this_month_core_units
      plans = @user.unit_month_plans.where(
        year_group_key: year_key,
        academic_year: academic_year,
        month: AcademicYear.current_month(@date)
      )
      plans.flat_map do |plan|
        next [] if Lesson.music_subject?(plan.subject) || Lesson.practice_unit?(plan.unit)

        Lesson.where(year_group_key: year_key, subject: plan.subject, unit: plan.unit).ordered.to_a
      end
    end

    def preferred_core_subject?(subject)
      return false if Lesson.music_subject?(subject)

      allowed = @user.effective_preferred_subjects
      allowed.nil? || allowed.include?(subject)
    end

    # One lesson per subject first, so the morning is not three Maths hours.
    # `offset` skips earlier weekdays so Tuesday is not a copy of Monday.
    def pick_round_robin(lessons, count, offset: 0)
      return [] if lessons.empty?

      queues = lessons.group_by(&:subject).transform_values(&:dup)
      subjects = lessons.map(&:subject).uniq
      skipped = 0
      picked = []

      while picked.size < count && queues.values.any?(&:any?)
        subjects.each do |subject|
          break if picked.size >= count

          next_lesson = queues[subject]&.shift
          next unless next_lesson

          if skipped < offset
            skipped += 1
            next
          end

          picked << next_lesson
        end
      end

      picked
    end

    def music_theory_lesson
      return if year_key.blank?

      candidates = Lesson.where(year_group_key: year_key)
        .music_subject
        .not_practice
        .ordered
        .to_a
      return if candidates.empty?

      playable_ids = @user.playable_lessons_relation.pluck(:id).to_set
      from_playable = prefer_oak_hub(candidates.select { |lesson| playable_ids.include?(lesson.id) })
      pool = from_playable.presence || (music_planned? ? [] : prefer_oak_hub(candidates))
      return if pool.empty?

      # Repeat the theory list across the week so hour 4 is rarely blank.
      pool[(weekday_index || 0) % pool.size]
    end

    def music_planned?
      @user.unit_month_plans.where(
        year_group_key: year_key,
        academic_year: academic_year
      ).where("LOWER(subject) = ?", Lesson::MUSIC_SUBJECT_NAME.downcase).exists?
    end

    def prefer_oak_hub(lessons)
      lessons.sort_by { |lesson| lesson.oak_hub? ? 0 : 1 }
    end

    def music_practice_lesson
      return if year_key.blank?

      MusicPracticeSeeder.ensure_for_year!(year_key)
    end

    def academic_year
      AcademicYear.start_year(@date)
    end
  end
end
