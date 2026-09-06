# frozen_string_literal: true

module Curriculum
  # Builds a Mon–Fri 09:00–15:15 timetable from a child's monthly unit picks.
  #
  # Think of it like packing a school bag for the week:
  # 1. Take the Oak units the parent put in this month.
  # 2. Line the lessons up in Oak order (unit, then lesson number).
  # 3. Pour them into 9:00–15:15 days, giving English, Maths, and Science more
  #    hours, and still sprinkling in the other subjects so the week is mixed.
  #    When English or Maths appears twice on a day, those two sit back to back.
  #
  # The first draft of each week is computed from the monthly plan. After
  # someone drags a block, that week is stored in week_lesson_slots so the
  # new order sticks.
  class WeekCalendar
    Period = Struct.new(:key, :starts_at, :ends_at, :kind, :label, keyword_init: true) do
      def start_minutes
        hours, minutes = starts_at.split(":").map(&:to_i)
        (hours * 60) + minutes
      end

      def end_minutes
        hours, minutes = ends_at.split(":").map(&:to_i)
        (hours * 60) + minutes
      end

      def duration_minutes
        end_minutes - start_minutes
      end

      # Minutes after 09:00 — used to paint the block on the calendar.
      def offset_minutes
        start_minutes - DAY_START_MINUTES
      end

      def lesson?
        kind == :lesson
      end
    end
    Slot = Struct.new(:date, :period, :lesson, :completed, keyword_init: true)
    Week = Struct.new(:monday, :dates, :slots, :subject_counts, keyword_init: true)
    Result = Struct.new(
      :child, :month, :academic_year, :weeks, :selected_week, :today, :has_units, :customized,
      keyword_init: true
    ) do
      def month_label
        AcademicYear.label_for(month)
      end

      def week_label
        return "" unless selected_week

        first = selected_week.dates.first
        last = selected_week.dates.last
        return "" unless first && last

        "#{first.strftime('%-d')}–#{last.strftime('%-d %B %Y')}"
      end

      def mondays
        weeks.map(&:monday)
      end

      def prev_monday
        return nil unless selected_week

        idx = mondays.index(selected_week.monday)
        idx&.positive? ? mondays[idx - 1] : nil
      end

      def next_monday
        return nil unless selected_week

        idx = mondays.index(selected_week.monday)
        idx ? mondays[idx + 1] : nil
      end

      def slot_at(date, period)
        return nil unless selected_week

        selected_week.slots.find { |slot| slot.date == date && slot.period.key == period.key }
      end
    end

    DAY_START_MINUTES = 9 * 60
    DAY_END_MINUTES = (15 * 60) + 15
    DAY_MINUTES = DAY_END_MINUTES - DAY_START_MINUTES
    PIXELS_PER_MINUTE = 1.35
    # Matching empty strips above 09:00 and below 15:15 so the first
    # and last lesson blocks are not glued to the frame.
    GUTTER_TOP_PX = 28
    GUTTER_BOTTOM_PX = 28

    # A 09:00–15:15 day: five hour-long lessons, 15-minute comfort breaks, 30-minute lunch.
    PERIODS = [
      Period.new(key: "p1", starts_at: "09:00", ends_at: "10:00", kind: :lesson, label: "Lesson"),
      Period.new(key: "b1", starts_at: "10:00", ends_at: "10:15", kind: :break, label: "Comfort break"),
      Period.new(key: "p2", starts_at: "10:15", ends_at: "11:15", kind: :lesson, label: "Lesson"),
      Period.new(key: "b2", starts_at: "11:15", ends_at: "11:30", kind: :break, label: "Comfort break"),
      Period.new(key: "p3", starts_at: "11:30", ends_at: "12:30", kind: :lesson, label: "Lesson"),
      Period.new(key: "lunch", starts_at: "12:30", ends_at: "13:00", kind: :lunch, label: "Lunch"),
      Period.new(key: "p4", starts_at: "13:00", ends_at: "14:00", kind: :lesson, label: "Lesson"),
      Period.new(key: "b3", starts_at: "14:00", ends_at: "14:15", kind: :break, label: "Comfort break"),
      Period.new(key: "p5", starts_at: "14:15", ends_at: "15:15", kind: :lesson, label: "Lesson")
    ].freeze

    TEACHING_PERIODS = PERIODS.select(&:lesson?).freeze
    HOUR_MARKS = %w[09:00 10:00 11:00 12:00 13:00 14:00 15:00 15:15].freeze
    WEEKDAYS = (0..4).freeze

    # Higher numbers mean more lessons of that subject each week.
    CORE_WEIGHTS = {
      "english" => 5,
      "mathematics" => 5,
      "maths" => 5,
      "science" => 4,
      "biology" => 3,
      "chemistry" => 3,
      "physics" => 3
    }.freeze
    OTHER_WEIGHT = 2
    # Foundation subjects still appear, but they should not take over a week.
    MAX_OTHER_PER_WEEK = 2
    # English / Maths / Science keep a heavier weekly share when lessons remain.
    MIN_CORE_PER_WEEK = 3
    # English and Maths often appear twice in a day. Those two should sit
    # next to each other (a "double"), with only a short break between.
    DOUBLE_UP_SUBJECTS = %w[english mathematics maths].freeze
    # Teaching periods that follow another lesson after a short break.
    # p4 follows lunch, so it is not a double with p3.
    BACK_TO_BACK_FOLLOWERS = %w[p2 p3 p5].freeze
    BACK_TO_BACK_PAIRS = [
      %w[p1 p2],
      %w[p2 p3],
      %w[p4 p5]
    ].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(child:, month: nil, academic_year: nil, week_monday: nil, today: Date.current, completed_lesson_ids: nil)
      @child = child
      @today = today.to_date
      @academic_year = academic_year || AcademicYear.start_year(@today)
      @month = month || AcademicYear.current_month(@today)
      @requested_monday = week_monday
      @completed_lesson_ids = Array(completed_lesson_ids).to_set
    end

    def call
      weeks = build_weeks
      selected = pick_week(weeks)
      Result.new(
        child: @child,
        month: @month,
        academic_year: @academic_year,
        weeks: weeks,
        selected_week: selected,
        today: @today,
        has_units: month_units.any?,
        customized: selected.present? && self.class.saved_scope(@child, selected.dates).exists?
      )
    end

    def self.core_subject?(subject)
      CORE_WEIGHTS.key?(normalize_subject(subject))
    end

    def self.weight_for(subject)
      CORE_WEIGHTS.fetch(normalize_subject(subject), OTHER_WEIGHT)
    end

    def self.double_up?(subject)
      DOUBLE_UP_SUBJECTS.include?(normalize_subject(subject))
    end

    def self.back_to_back?(period_keys)
      keys = Array(period_keys).map(&:to_s).uniq
      return false if keys.size < 2

      keys.combination(2).any? { |pair| BACK_TO_BACK_PAIRS.include?(pair.sort) }
    end

    def self.current_period_key(time = Time.current)
      minutes = (time.hour * 60) + time.min
      PERIODS.each do |period|
        start_h, start_m = period.starts_at.split(":").map(&:to_i)
        end_h, end_m = period.ends_at.split(":").map(&:to_i)
        start_min = (start_h * 60) + start_m
        end_min = (end_h * 60) + end_m
        return period.key if minutes >= start_min && minutes < end_min
      end
      nil
    end

    def self.normalize_subject(subject)
      subject.to_s.downcase.strip
    end

    def self.teaching_period_keys
      TEACHING_PERIODS.map(&:key)
    end

    def self.period_for(key)
      PERIODS.find { |period| period.key == key.to_s }
    end

    def self.clock_top(offset_minutes)
      GUTTER_TOP_PX + (offset_minutes * PIXELS_PER_MINUTE)
    end

    def self.block_style(period)
      top = clock_top(period.offset_minutes)
      height = period.duration_minutes * PIXELS_PER_MINUTE
      "top: #{top}px; height: #{height}px;"
    end

    def self.day_height_style
      "height: #{GUTTER_TOP_PX + (DAY_MINUTES * PIXELS_PER_MINUTE) + GUTTER_BOTTOM_PX}px;"
    end

    def self.hour_mark_style(time)
      hours, minutes = time.split(":").map(&:to_i)
      top = clock_top((hours * 60) + minutes - DAY_START_MINUTES)
      "top: #{top}px;"
    end

    # Pixel offset for the red "now" line. Nil when we are outside 09:00–15:15.
    def self.now_line_style(time = Time.current)
      minutes = (time.hour * 60) + time.min
      return nil if minutes < DAY_START_MINUTES || minutes > DAY_END_MINUTES

      "top: #{clock_top(minutes - DAY_START_MINUTES)}px;"
    end

    # Swap two teaching blocks and remember the new week.
    def self.swap!(child:, from_date:, from_period:, to_date:, to_period:, month:, week_monday: nil)
      result = call(child: child, month: month, week_monday: week_monday)
      week = result.selected_week
      return false unless week

      persist_week!(child, week) unless saved_scope(child, week.dates).exists?
      from_date = Date.iso8601(from_date.to_s)
      to_date = Date.iso8601(to_date.to_s)
      left = child.week_lesson_slots.find_by(slot_date: from_date, period_key: from_period.to_s)
      right = child.week_lesson_slots.find_by(slot_date: to_date, period_key: to_period.to_s)
      return false unless left && right

      left_id = left.lesson_id
      left.update!(lesson_id: right.lesson_id)
      right.update!(lesson_id: left_id)
      true
    end

    def self.reset_week!(child:, dates:)
      saved_scope(child, dates).delete_all
    end

    def self.persist_week!(child, week)
      week.slots.each do |slot|
        next unless slot.period.lesson?

        child.week_lesson_slots.find_or_initialize_by(
          slot_date: slot.date,
          period_key: slot.period.key
        ).update!(lesson_id: slot.lesson&.id)
      end
    end

    def self.saved_scope(child, dates)
      child.week_lesson_slots.where(slot_date: dates)
    end

    private

    def year_key
      @child.current_year_group_key
    end

    def month_units
      return @month_units if defined?(@month_units)

      @month_units = planned_units.presence || []
    end

    def planned_units
      return [] if year_key.blank?

      @child.unit_month_plans.where(
        year_group_key: year_key,
        academic_year: @academic_year,
        month: @month
      ).map { |plan| { subject: plan.subject, unit: plan.unit } }
    end

    def lesson_queues
      queues = Hash.new { |hash, subject| hash[subject] = [] }
      return queues if year_key.blank? || month_units.empty?

      month_units.each do |row|
        Lesson.where(year_group_key: year_key, subject: row[:subject], unit: row[:unit])
          .ordered
          .each { |lesson| queues[lesson.subject] << lesson }
      end
      queues
    end

    def build_weeks
      queues = lesson_queues
      mondays = AcademicYear.school_week_mondays(@month, @academic_year)
      order = allocation_order(mondays)
      filled = {}

      # In the current month, pack remaining weeks first so "this week" is never
      # an empty leftover after earlier weeks have used every lesson.
      order.each_with_index do |monday, index|
        dates = school_dates_for(monday)
        weeks_left = order.size - index
        last_week = index == order.size - 1
        slots = fill_week(dates, queues, weeks_left, last_week: last_week)
        apply_saved_slots!(slots, dates)
        filled[monday] = Week.new(
          monday: monday,
          dates: dates,
          slots: slots,
          subject_counts: count_subjects(slots)
        )
      end

      mondays.map { |monday| filled[monday] || empty_week(monday) }
    end

    def allocation_order(mondays)
      return mondays unless current_plan_month?

      upcoming = mondays.select { |monday| monday >= current_school_monday }
      upcoming.presence || mondays
    end

    # Before term starts (e.g. Sunday 6 September), pack from Monday the 7th,
    # not the August Monday that still contains 1–4 September.
    def current_school_monday
      first = AcademicYear.first_school_monday(@month, @academic_year)
      [ AcademicYear.monday_of(@today), first ].max
    end

    def empty_week(monday)
      dates = school_dates_for(monday)
      slots = dates.flat_map do |date|
        PERIODS.map { |period| Slot.new(date: date, period: period, lesson: nil, completed: false) }
      end
      apply_saved_slots!(slots, dates)
      Week.new(monday: monday, dates: dates, slots: slots, subject_counts: count_subjects(slots))
    end

    def current_plan_month?
      @month == AcademicYear.current_month(@today) &&
        @academic_year == AcademicYear.start_year(@today)
    end

    def apply_saved_slots!(slots, dates)
      saved = self.class.saved_scope(@child, dates).includes(:lesson)
      return if saved.none?

      by_key = saved.index_by { |row| [ row.slot_date.to_date, row.period_key.to_s ] }
      slots.each do |slot|
        next unless slot.period.lesson?

        row = by_key[[ slot.date.to_date, slot.period.key.to_s ]]
        next unless row

        slot.lesson = row.lesson
        slot.completed = slot.lesson.present? && @completed_lesson_ids.include?(slot.lesson.id)
      end
    end

    def school_dates_for(monday)
      AcademicYear.school_dates_for_monday(monday, @month, @academic_year)
    end

    def fill_week(dates, queues, weeks_left, last_week:)
      slot_count = dates.size * TEACHING_PERIODS.size
      quotas = weekly_quotas(queues, slot_count, weeks_left, last_week: last_week)
      used = Hash.new(0)
      last_by_date = {}
      placed = {}

      # Fill 9:00 across Mon–Fri first, then 10:00, and so on. That keeps
      # Thursday and Friday from becoming leftover empty days.
      TEACHING_PERIODS.each do |period|
        dates.each do |date|
          subject = pick_subject(queues, quotas, used, last_by_date[date], period)
          lesson = subject && queues[subject].shift
          used[subject] += 1 if subject
          last_by_date[date] = subject
          placed[[ date, period.key ]] = Slot.new(
            date: date,
            period: period,
            lesson: lesson,
            completed: lesson.present? && @completed_lesson_ids.include?(lesson.id)
          )
        end
      end

      # If English or Maths landed twice on a day but not next to each
      # other, slide those two into a back-to-back pair.
      dates.each { |date| pair_double_lessons!(placed, date) }

      dates.flat_map do |date|
        PERIODS.map do |period|
          next placed[[ date, period.key ]] if period.kind == :lesson

          Slot.new(date: date, period: period, lesson: nil, completed: false)
        end
      end
    end

    def weekly_quotas(queues, slot_count, weeks_left, last_week:)
      subjects = queues.keys.select { |subject| queues[subject].any? }
      return {} if subjects.empty? || slot_count <= 0

      weeks_left = [ weeks_left, 1 ].max
      quotas = {}

      subjects.each do |subject|
        remaining = queues[subject].size
        # Spread leftover lessons across the weeks still to come.
        pace = (remaining.to_f / weeks_left).ceil
        quotas[subject] = if self.class.core_subject?(subject)
          [ [ pace, MIN_CORE_PER_WEEK ].max, remaining, slot_count ].min
        else
          [ pace, MAX_OTHER_PER_WEEK, remaining, slot_count ].min
        end
      end

      total = quotas.values.sum
      shrink_quotas(quotas, total - slot_count) if total > slot_count
      spare = slot_count - quotas.values.sum
      if spare.positive?
        # Keep most leftovers for later weeks, but fill enough of the day
        # that Thursday and Friday are still real school days.
        extra = last_week ? spare : [ spare, (slot_count / 5.0).ceil ].min
        grow_quotas(quotas, queues, extra)
      end

      quotas
    end

    def shrink_quotas(quotas, excess)
      # Trim foundation subjects first so core hours stay protected.
      quotas.keys.sort_by { |subject| [ self.class.weight_for(subject), subject ] }.each do |subject|
        break if excess <= 0

        take = [ quotas[subject], excess ].min
        quotas[subject] -= take
        excess -= take
      end
    end

    def grow_quotas(quotas, queues, spare)
      # Extra hours go to English / Maths / Science first, then everyone else.
      order = quotas.keys.sort_by { |subject| [ self.class.core_subject?(subject) ? 0 : 1, -self.class.weight_for(subject), subject ] }

      200.times do
        break if spare <= 0

        progressed = false
        order.each do |subject|
          break if spare <= 0
          next if quotas[subject] >= queues[subject].size
          next if !self.class.core_subject?(subject) && quotas[subject] >= MAX_OTHER_PER_WEEK && core_can_take_more?(quotas, queues)

          quotas[subject] += 1
          spare -= 1
          progressed = true
        end

        break unless progressed
      end
    end

    def core_can_take_more?(quotas, queues)
      quotas.any? do |subject, count|
        self.class.core_subject?(subject) && count < queues[subject].size
      end
    end

    def pick_subject(queues, quotas, used, last_subject, period)
      candidates = quotas.keys.select do |subject|
        queues[subject].any? && used[subject] < quotas[subject]
      end
      return nil if candidates.empty?

      # Same English or Maths again, but only when the last lesson is
      # still next door (not across lunch).
      if last_subject &&
          self.class.double_up?(last_subject) &&
          BACK_TO_BACK_FOLLOWERS.include?(period.key) &&
          candidates.include?(last_subject)
        return last_subject
      end

      # Otherwise prefer a different subject so the rest of the day stays mixed.
      pool = candidates.reject { |subject| subject == last_subject }
      pool = candidates if pool.empty?

      # Pick the subject that is furthest behind its weekly share.
      pool.min_by do |subject|
        weight = self.class.weight_for(subject)
        [ used[subject].to_f / weight, subject ]
      end
    end

    def pair_double_lessons!(placed, date)
      keys = TEACHING_PERIODS.map(&:key)
      slots = keys.map { |key| placed[[ date, key ]] }

      slots.filter_map { |slot| slot.lesson&.subject }.uniq.each do |subject|
        next unless self.class.double_up?(subject)

        positions = slots.each_index.select { |index| slots[index].lesson&.subject == subject }
        next if positions.size < 2
        next if self.class.back_to_back?(positions.map { |index| keys[index] })

        pair = preferred_double_pair(positions)
        occupy_pair!(slots, subject, pair)
      end
    end

    # Morning doubles first (p1+p2 or p2+p3). Afternoon uses p4+p5.
    # We never pair p3 with p4 because lunch sits between them.
    def preferred_double_pair(positions)
      morning = positions.select { |index| index <= 2 }
      return [ 3, 4 ] if morning.empty?
      return [ 0, 1 ] if morning.include?(0) || morning.include?(1)

      [ 1, 2 ]
    end

    def occupy_pair!(slots, subject, pair)
      donors = slots.each_index.select { |index| slots[index].lesson&.subject == subject }

      pair.each do |target|
        next if slots[target].lesson&.subject == subject

        donor = donors.find { |index| pair.exclude?(index) }
        next unless donor

        swap_slot_lessons!(slots[target], slots[donor])
        donors.delete(donor)
        donors << target
      end
    end

    def swap_slot_lessons!(left, right)
      left.lesson, right.lesson = right.lesson, left.lesson
      left.completed, right.completed = right.completed, left.completed
    end

    def count_subjects(slots)
      counts = Hash.new(0)
      slots.each do |slot|
        next unless slot.lesson

        counts[slot.lesson.subject] += 1
      end
      counts
    end

    def pick_week(weeks)
      return nil if weeks.empty?

      requested = parse_monday(@requested_monday)
      return weeks.find { |week| week.monday == requested } || weeks.first if requested

      target = current_school_monday
      weeks.find { |week| week.monday == target } ||
        weeks.find { |week| week.monday >= target } ||
        weeks.first
    end

    def parse_monday(value)
      return value.beginning_of_week(:monday) if value.respond_to?(:beginning_of_week)
      return nil if value.blank?

      Date.iso8601(value.to_s).beginning_of_week(:monday)
    rescue ArgumentError
      nil
    end
  end
end
