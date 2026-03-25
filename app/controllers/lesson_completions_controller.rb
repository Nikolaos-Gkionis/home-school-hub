# frozen_string_literal: true

class LessonCompletionsController < ApplicationController
  before_action :authenticate_user!

  def create
    @lesson = Lesson.find(params[:lesson_id])
    ProgressTracker.mark_complete(user: current_user, lesson: @lesson)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to dashboard_path(lesson_id: @lesson.id), notice: "Lesson marked complete." }
    end
  end
end
