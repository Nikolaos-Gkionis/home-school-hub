# frozen_string_literal: true

module Parent
  class FamiliesController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_parent!

    def show
      @children = current_user.children.order(:email)
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
      @child_name = primary_child_name(@child)
    end

    def update_child
      @child = current_user.children.find(params[:id])
      new_email = child_params[:email].to_s.strip
      new_name = child_params[:child_name].to_s.strip

      ActiveRecord::Base.transaction do
        @child.update!(email: new_email)
        @child.learners.update_all(display_label: new_name) if new_name.present?
      end

      redirect_to parent_family_path, notice: "Updated child details for #{new_email}."
    rescue ActiveRecord::RecordInvalid
      @child_name = new_name
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
      params.require(:child).permit(:child_name, :email)
    end

    def primary_child_name(child)
      child.learners.order(:position).first&.display_name || child.email
    end
  end
end
