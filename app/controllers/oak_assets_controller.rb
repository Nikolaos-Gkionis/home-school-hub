# frozen_string_literal: true

class OakAssetsController < ApplicationController
  before_action :authenticate_user!

  def show
    @lesson = find_lesson
    Oak::LessonHydrator.call(@lesson) if @lesson.assets_list.blank?

    type = params[:type].to_s
    asset = @lesson.assets_list.find { |a| a["type"] == type }
    return head :not_found if asset.blank?

    uri = URI(asset["url"])
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = Oak::ApiClient.authorization_header
      http.request(req)
    end

    if response.is_a?(Net::HTTPRedirection)
      redirect_to response["location"], allow_other_host: true
      return
    end
    if response.is_a?(Net::HTTPSuccess)
      send_data response.body,
                type: response["Content-Type"] || "application/octet-stream",
                disposition: "inline"
      return
    end

    head :bad_gateway
  end

  private

  def find_lesson
    current_user.visible_lessons_relation.find(params[:lesson_id])
  end
end
