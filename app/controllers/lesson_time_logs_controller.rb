# frozen_string_literal: true

class LessonTimeLogsController < ApplicationController
  before_action :authenticate_user!

  def create
    lesson = current_user.visible_lessons_relation.find(params[:lesson_id])
    seconds = params[:seconds].to_i.clamp(0, 3600)
    LessonTimeLog.append_seconds!(user: current_user, lesson: lesson, seconds: seconds)
    head :ok
  end
end
