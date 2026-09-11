# frozen_string_literal: true

require "test_helper"

class UnitMonthPlanPacingTest < ActiveSupport::TestCase
  setup do
    travel_to Date.new(2026, 9, 15)
    @parent = User.create!(
      email: "plan-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @child = User.create!(
      email: "plan-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7")
    @child.update!(active_learner: @child.learners.first)

    @sept = create_lesson(unit: "September unit", slug: "sept-unit")
    @oct = create_lesson(unit: "October unit", slug: "oct-unit")
  end

  test "units stay unlocked when the child has no plan" do
    assert_not @child.pacing_active?
    assert @child.unit_unlocked?("English", "October unit")
    assert_includes @child.playable_lessons_relation.pluck(:id), @oct.id
  end

  test "a plan locks future months and unassigned units" do
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "English",
      unit: "September unit"
    )
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 10,
      subject: "English",
      unit: "October unit"
    )

    assert @child.pacing_active?
    assert @child.unit_unlocked?("English", "September unit")
    assert_not @child.unit_unlocked?("English", "October unit")
    ids = @child.playable_lessons_relation.pluck(:id)
    assert_includes ids, @sept.id
    assert_not_includes ids, @oct.id
  end

  test "plans on another year group do not unlock this year" do
    @child.unit_month_plans.create!(
      year_group_key: "year_8",
      academic_year: 2026,
      month: 9,
      subject: "English",
      unit: "September unit"
    )

    assert_not @child.pacing_active?
    assert @child.unit_unlocked?("English", "October unit")
  end

  test "spread remaining units fills empty months" do
    count = Curriculum::SpreadUnits.call(child: @child, academic_year: 2026)
    assert_equal 2, count
    months = @child.unit_month_plans.order(:month).pluck(:month, :unit)
    assert_equal 2, months.size
    assert_equal months.map(&:first).uniq.size, months.size
  end

  test "spread remaining units skips Music and practice" do
    Lesson.create!(
      year_group_key: "year_7",
      subject: "Music",
      unit: "Notation",
      unit_position: 1,
      title: "Music 1",
      external_url: "https://www.thenational.academy/pupils/lessons/spread-music-1",
      oak_lesson_slug: "spread-music-1",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
    Curriculum::MusicPracticeSeeder.ensure_for_year!("year_7")

    count = Curriculum::SpreadUnits.call(child: @child, academic_year: 2026)
    units = @child.unit_month_plans.pluck(:subject, :unit)
    assert_equal 2, count
    assert_not(units.any? { |subject, _unit| Lesson.music_subject?(subject) })
    assert_not(units.any? { |_subject, unit| Lesson.practice_unit?(unit) })
  end

  test "practice lessons stay playable when pacing is on" do
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "English",
      unit: "September unit"
    )
    practice = Curriculum::MusicPracticeSeeder.ensure_for_year!("year_7")

    assert @child.pacing_active?
    assert @child.unit_unlocked?(practice.subject, practice.unit)
    assert_includes @child.playable_lessons_relation.pluck(:id), practice.id
  end

  private

  def create_lesson(unit:, slug:)
    Lesson.create!(
      year_group_key: "year_7",
      subject: "English",
      unit: unit,
      unit_position: slug == "sept-unit" ? 1 : 2,
      title: unit,
      external_url: "https://www.thenational.academy/pupils/lessons/#{slug}",
      oak_lesson_slug: slug,
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
  end
end
