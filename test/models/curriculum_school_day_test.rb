# frozen_string_literal: true

require "test_helper"

class CurriculumSchoolDayTest < ActiveSupport::TestCase
  setup do
    travel_to Date.new(2026, 9, 14) # Monday, so Day matches the first column of Week
    @parent = User.create!(
      email: "school-day-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @child = User.create!(
      email: "school-day-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7")
    @child.update!(active_learner: @child.learners.first)

    @maths_a = oak_lesson(subject: "Mathematics", unit: "Number", title: "Maths 1", slug: "sd-maths-1")
    @maths_b = oak_lesson(subject: "Mathematics", unit: "Number", title: "Maths 2", slug: "sd-maths-2", position: 2)
    @english = oak_lesson(subject: "English", unit: "Poetry", title: "English 1", slug: "sd-english-1")
    @science = oak_lesson(subject: "Science", unit: "Cells", title: "Science 1", slug: "sd-science-1")
    @music = oak_lesson(subject: "Music", unit: "Notation", title: "Music theory 1", slug: "sd-music-1")
  end

  test "assigns three core hours plus music theory and practice" do
    plan_september_units
    day = Curriculum::SchoolDay.call(@child)

    assert_equal [ 1, 2, 3, 4, 5 ], day.slots.map(&:hour)
    assert_equal [ :core, :core, :core, :music_theory, :music_practice ], day.slots.map(&:kind)
    assert_equal %w[09:00 10:15 11:30 13:00 14:15], day.slots.map(&:starts_at)
    assert_equal %w[p1 p2 p3 p4 p5], day.slots.map(&:key)

    core = day.morning_slots.map(&:lesson)
    assert_equal 3, core.compact.size
    core.each { |lesson| assert_not Lesson.music_subject?(lesson.subject) }

    theory = day.slots[3]
    assert_equal @music, theory.lesson
    assert Lesson.music_subject?(theory.lesson.subject)
    assert_not theory.lesson.practice?

    practice = day.slots[4].lesson
    assert practice.practice?
    assert_equal Lesson::MUSIC_SUBJECT_NAME, practice.subject
    assert_not practice.oak_hub?
  end

  test "timeline weaves comfort breaks and lunch around the five hours" do
    day = Curriculum::SchoolDay.call(@child)

    assert_equal %w[p1 b1 p2 b2 p3 lunch p4 b3 p5], day.timeline.map(&:key)
    assert_equal [ :break, :break, :break ], day.timeline.select(&:break?).map(&:kind)
    lunch = day.timeline.find(&:lunch?)
    assert_equal "12:30", lunch.starts_at
    assert_equal "13:00", lunch.ends_at
  end

  test "never puts non-music lessons in hours 4 and 5" do
    plan_september_units
    day = Curriculum::SchoolDay.call(@child)
    afternoon = day.afternoon_slots.map(&:lesson)

    afternoon.each do |lesson|
      assert lesson.present?
      assert Lesson.music_subject?(lesson.subject)
    end
  end

  test "never puts Music into hours 1 to 3" do
    plan_september_units
    day = Curriculum::SchoolDay.call(@child)

    day.morning_slots.each do |slot|
      next if slot.lesson.nil?

      assert_not Lesson.music_subject?(slot.lesson.subject)
      assert_not slot.lesson.practice?
    end
  end

  test "round-robins core hours across subjects" do
    plan_september_units
    subjects = Curriculum::SchoolDay.call(@child).morning_slots.map { |slot| slot.lesson.subject }

    assert_equal 3, subjects.uniq.size
    assert_includes subjects, "English"
    assert_includes subjects, "Mathematics"
    assert_includes subjects, "Science"
  end

  test "still shows assigned core lessons after they are completed" do
    plan_september_units
    day = Curriculum::SchoolDay.call(@child)
    assigned = day.morning_slots.map(&:lesson)
    assigned.each do |lesson|
      @child.lesson_completions.create!(lesson: lesson, completed_at: Time.current)
    end

    refreshed = Curriculum::SchoolDay.call(@child)
    assert_equal assigned, refreshed.morning_slots.map(&:lesson)
    assigned.each { |lesson| assert @child.completed?(lesson) }
  end

  test "Tuesday morning continues after Monday instead of repeating it" do
    plan_september_units
    monday = Curriculum::SchoolDay.call(@child, Date.new(2026, 9, 14))
    tuesday = Curriculum::SchoolDay.call(@child, Date.new(2026, 9, 15))

    assert_equal [ @maths_a, @english, @science ], monday.morning_slots.map(&:lesson)
    assert_equal [ @maths_b ], tuesday.morning_slots.filter_map(&:lesson)
  end

  test "weekend days have no school timetable" do
    saturday = Curriculum::SchoolDay.call(@child, Date.new(2026, 9, 19))
    assert saturday.weekend?
    assert_nil saturday.weekday_index
  end

  test "Friday of the third week in July is still in term" do
    day = Curriculum::SchoolDay.call(@child, Date.new(2027, 7, 23))
    assert day.in_term?
    assert_not day.holiday?
  end

  test "Monday after the third week in July is summer holiday" do
    day = Curriculum::SchoolDay.call(@child, Date.new(2027, 7, 26))
    assert_not day.in_term?
    assert day.holiday?
  end

  test "practice lessons stay playable when pacing is on" do
    plan_september_units
    practice = Curriculum::MusicPracticeSeeder.ensure_for_year!("year_7")

    assert @child.pacing_active?
    assert @child.unit_unlocked?(practice.subject, practice.unit)
    assert_includes @child.playable_lessons_relation.pluck(:id), practice.id
  end

  test "offers music theory even when Music is not on the year plan" do
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "English",
      unit: "Poetry"
    )

    day = Curriculum::SchoolDay.call(@child)
    assert_equal @music, day.slots[3].lesson
  end

  test "shows music hours when Music is filtered out of preferred subjects" do
    plan_september_units
    @child.active_learner.update!(preferred_subjects: [ "English", "Mathematics" ])

    day = Curriculum::SchoolDay.call(@child)
    core_subjects = day.morning_slots.filter_map { |slot| slot.lesson&.subject }
    assert_not_includes core_subjects, "Music"
    assert_includes core_subjects, "English"
    assert_equal @music, day.slots[3].lesson
    assert day.slots[4].lesson.practice?
  end

  test "does not fill empty core hours with music" do
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "Music",
      unit: "Notation"
    )

    day = Curriculum::SchoolDay.call(@child)
    assert day.morning_slots.all? { |slot| slot.lesson.nil? }
    assert_equal @music, day.slots[3].lesson
  end

  private

  def plan_september_units
    [
      [ "Mathematics", "Number" ],
      [ "English", "Poetry" ],
      [ "Science", "Cells" ],
      [ "Music", "Notation" ]
    ].each do |subject, unit|
      @child.unit_month_plans.create!(
        year_group_key: "year_7",
        academic_year: 2026,
        month: 9,
        subject: subject,
        unit: unit
      )
    end
  end

  def oak_lesson(subject:, unit:, title:, slug:, position: 1)
    Lesson.create!(
      year_group_key: "year_7",
      subject: subject,
      unit: unit,
      unit_position: 1,
      title: title,
      external_url: "https://www.thenational.academy/pupils/lessons/#{slug}",
      oak_lesson_slug: slug,
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: position
    )
  end
end
