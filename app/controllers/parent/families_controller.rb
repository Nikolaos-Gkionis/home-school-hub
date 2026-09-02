# frozen_string_literal: true

module Parent
  class FamiliesController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_parent!

    def show
      @children = current_user.children.includes(:learners, :active_learner).order(:email)
      @sent_invitations = current_user.invitations.order(created_at: :desc)
    end

    def child
      @child = current_user.children.find(params[:id])
      @metrics = Insights::Summary.call(viewer: current_user, scope_user: @child)
      @eligible_checkpoint_subjects = CheckpointTest.eligible_subjects_for(@child)
      @checkpoint_tests = CheckpointTest.where(parent: current_user, child: @child).recent_first.limit(10)
    end

    def edit_child
      @child = current_user.children.find(params[:id])
      @child_name = @child.family_display_name
      @year_group_key = @child.current_year_group_key
    end

    def update_child
      @child = current_user.children.find(params[:id])
      new_email = child_params[:email].to_s.strip
      new_name = child_params[:child_name].to_s.strip
      new_year = child_params[:year_group_key].to_s

      unless Curriculum::YearGroups.all_year_keys.include?(new_year)
        @child_name = new_name
        @year_group_key = @child.current_year_group_key
        redirect_to parent_edit_child_path(@child), alert: "That school year is not available."
        return
      end

      ActiveRecord::Base.transaction do
        @child.update!(email: new_email)
        @child.learners.update_all(display_label: new_name) if new_name.present?
        @child.move_to_year_group!(new_year)
      end

      year_label = Curriculum::YearGroups.label_for_year(new_year)
      redirect_to parent_family_path, notice: "Updated #{new_email} — now on #{year_label}."
    rescue ActiveRecord::RecordInvalid
      @child_name = new_name
      @year_group_key = new_year.presence || @child.current_year_group_key
      render :edit_child, status: :unprocessable_entity
    end

    def destroy_child
      child = current_user.children.find(params[:id])
      email = child.email
      child.update!(
        role: User::ROLE_PARENT,
        parent_id: nil,
        active_learner: nil
      )
      redirect_to parent_family_path, notice: "Removed #{email} from your family."
    end

    private

    def child_params
      params.require(:child).permit(:child_name, :email, :year_group_key)
    end
  end
end
