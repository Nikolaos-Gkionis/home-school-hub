# frozen_string_literal: true

module Parent
  class CheckpointTestsController < ApplicationController
    include RoleAccess

    before_action :authenticate_user!
    before_action :require_parent!
    before_action :set_child
    before_action :set_checkpoint_test, only: [ :show, :answer_key ]

    def create
      subject = params[:subject].to_s
      unless CheckpointTest.eligible_subjects_for(@child).include?(subject)
        redirect_to parent_child_path(@child), alert: "This subject is not ready yet. A checkpoint test needs at least #{CheckpointTest::MIN_COMPLETED_LESSONS} completed lessons."
        return
      end

      checkpoint_test = CheckpointTests::Generator.call(parent: current_user, child: @child, subject: subject)
      redirect_to parent_child_checkpoint_test_path(@child, checkpoint_test), notice: "Checkpoint test created for #{subject}."
    rescue CheckpointTests::Generator::Error => e
      redirect_to parent_child_path(@child), alert: e.message
    end

    def show; end

    def answer_key; end

    private

    def set_child
      @child = current_user.children.find(params[:child_id])
    end

    def set_checkpoint_test
      @checkpoint_test = CheckpointTest.find_by!(id: params[:id], parent: current_user, child: @child)
      @questions = Array(@checkpoint_test.questions_json)
    end
  end
end
