# frozen_string_literal: true

require "test_helper"

class CurriculumCatalogueResetTest < ActiveSupport::TestCase
  setup do
    @parent = User.create!(
      email: "reset-parent@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_PARENT,
      setup_completed_at: Time.current
    )
    @child = User.create!(
      email: "reset-child@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: User::ROLE_LEARNER,
      parent: @parent,
      setup_completed_at: Time.current
    )
    @child.learners.create!(year_group_key: "year_7", preferred_subjects: [ "French" ])
    @child.update!(active_learner: @child.learners.first)

    @lesson = Lesson.create!(
      year_group_key: "year_7",
      subject: "French",
      unit: "Greetings",
      unit_position: 1,
      title: "Bonjour",
      external_url: "https://www.thenational.academy/pupils/lessons/reset-bonjour",
      oak_lesson_slug: "reset-bonjour",
      content_mode: Lesson::CONTENT_MODE_OAK_HUB,
      position: 1
    )
    @child.unit_month_plans.create!(
      year_group_key: "year_7",
      academic_year: 2026,
      month: 9,
      subject: "French",
      unit: "Greetings"
    )
    @child.lesson_completions.create!(lesson: @lesson, completed_at: Time.current)
    @child.update!(last_active_lesson: @lesson)
  end

  test "wipes lessons and year plans, then puts practice rows back" do
    Curriculum::CatalogueReset.call

    assert_not Lesson.exists?(id: @lesson.id)
    assert_equal 0, UnitMonthPlan.count
    assert_equal 0, LessonCompletion.count
    assert_nil @child.reload.last_active_lesson_id
    assert_nil @child.learners.first.preferred_subjects
    assert Lesson.practice.exists?
    assert_equal [ "English", "History", "Mathematics", "Music", "Science" ],
      OakCurriculum.hub_subject_filter_options
  end
end
