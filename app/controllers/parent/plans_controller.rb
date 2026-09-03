# frozen_string_literal: true

module Parent
  class PlansController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_parent!
    before_action :set_child

    def show
      load_plan_context
    end

    def update
      load_plan_context
      wanted = Array(params[:assigned_units]).map(&:to_s).reject(&:blank?).to_set
      apply_assignments!(wanted)
      redirect_to parent_child_plan_path(@child, month: @month), notice: "Saved #{Curriculum::AcademicYear.label_for(@month)}."
    end

    def spread
      count = Curriculum::SpreadUnits.call(child: @child)
      month = params[:month].presence
      redirect_to parent_child_plan_path(@child, month: month),
        notice: (count.positive? ? "Spread #{count} remaining units across the year." : "Every unit is already on the plan.")
    end

    private

    def set_child
      @child = current_user.children.find(params[:child_id])
    end

    def load_plan_context
      @academic_year = Curriculum::AcademicYear.start_year
      @year_key = @child.current_year_group_key
      @month = selected_month
      @units_by_subject = units_for_year
      @assigned_keys = this_month_plans.map(&:unit_key).to_set
      @plans_by_unit_key = all_year_plans.index_by(&:unit_key)
      @month_counts = month_progress_counts
    end

    def selected_month
      month = params[:month].to_i
      Curriculum::AcademicYear.plan_month?(month) ? month : Curriculum::AcademicYear.current_month
    end

    def this_month_plans
      return UnitMonthPlan.none if @year_key.blank?

      @child.unit_month_plans.where(
        year_group_key: @year_key,
        academic_year: @academic_year,
        month: @month
      )
    end

    def all_year_plans
      return UnitMonthPlan.none if @year_key.blank?

      @child.unit_month_plans.where(year_group_key: @year_key, academic_year: @academic_year)
    end

    def units_for_year
      return {} if @year_key.blank?

      Lesson.where(year_group_key: @year_key)
        .where.not(subject: Lesson::OAK_SUBJECT_NAME)
        .ordered
        .select(:subject, :unit, :unit_position)
        .group_by(&:subject)
        .transform_values do |lessons|
          lessons.uniq { |l| l.unit }.sort_by { |l| l.unit_position || 9999 }
        end
    end

    def apply_assignments!(wanted_keys)
      return if @year_key.blank?

      this_month_plans.find_each do |plan|
        plan.destroy! unless wanted_keys.include?(plan.unit_key)
      end

      wanted_keys.each do |key|
        subject, unit = Lesson.parse_unit_key(key)
        next if subject.blank? || unit.blank?
        next if this_month_plans.exists?(subject: subject, unit: unit)

        @child.unit_month_plans.where(
          year_group_key: @year_key,
          academic_year: @academic_year,
          subject: subject,
          unit: unit
        ).delete_all

        @child.unit_month_plans.create!(
          year_group_key: @year_key,
          academic_year: @academic_year,
          month: @month,
          subject: subject,
          unit: unit
        )
      end
    end

    def month_progress_counts
      completed = @child.lesson_completions.pluck(:lesson_id).to_set
      Curriculum::AcademicYear::PLAN_MONTHS.index_with do |month|
        plans = @child.unit_month_plans.where(
          year_group_key: @year_key,
          academic_year: @academic_year,
          month: month
        )
        next [ 0, 0 ] if @year_key.blank? || plans.none?

        done = plans.count do |plan|
          ids = Lesson.where(year_group_key: @year_key, subject: plan.subject, unit: plan.unit).pluck(:id)
          ids.any? && ids.all? { |id| completed.include?(id) }
        end
        [ done, plans.size ]
      end
    end
  end
end
