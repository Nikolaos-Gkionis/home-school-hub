# frozen_string_literal: true

class OakAssetsController < ApplicationController
  before_action :authenticate_user!

  OAK_API_HOST = URI(Oak::ApiClient::BASE).host.freeze

  # Oak lesson assets — extensions/MIME hints so macOS associates the right app (Preview, Keynote, etc.).
  TYPE_EXTENSIONS = {
    "slideDeck" => "pptx",
    "worksheet" => "pdf",
    "worksheetAnswers" => "pdf",
    "supplementaryResource" => "pdf",
    "starterQuiz" => "pdf",
    "starterQuizAnswers" => "pdf",
    "exitQuiz" => "pdf",
    "exitQuizAnswers" => "pdf"
  }.freeze

  TYPE_CONTENT_TYPES = {
    "slideDeck" => "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "worksheet" => "application/pdf",
    "worksheetAnswers" => "application/pdf",
    "supplementaryResource" => "application/pdf",
    "starterQuiz" => "application/pdf",
    "starterQuizAnswers" => "application/pdf",
    "exitQuiz" => "application/pdf",
    "exitQuizAnswers" => "application/pdf"
  }.freeze

  def show
    @lesson = find_lesson
    Oak::LessonHydrator.call(@lesson) if @lesson.assets_list.blank?

    type = params[:type].to_s
    asset = @lesson.assets_list.find { |a| a["type"] == type }
    return head :not_found if asset.blank?

    uri = URI(asset["url"])

    if type == "video"
      stream_video_through(uri)
    else
      proxy_download(type, uri)
    end
  end

  private

  def find_lesson
    current_user.visible_lessons_relation.find(params[:lesson_id])
  end

  # One hop only: let the browser stream large video directly from the CDN.
  def stream_video_through(uri)
    response = oak_http_get(uri, with_auth: uri.host == OAK_API_HOST)

    if response.is_a?(Net::HTTPRedirection)
      redirect_to response["location"], allow_other_host: true
      return
    end

    if response.is_a?(Net::HTTPSuccess)
      ct = response["Content-Type"].presence || "video/mp4"
      send_data response.body,
                type: ct,
                disposition: "inline"
      return
    end

    head :bad_gateway
  end

  # Follow redirects (same as browser would), then send as attachment with a real filename for macOS.
  def proxy_download(type, uri)
    with_auth = uri.host == OAK_API_HOST
    response = nil
    10.times do
      response = oak_http_get(uri, with_auth: with_auth)
      if response.is_a?(Net::HTTPRedirection) && response["location"].present?
        uri = resolve_redirect_uri(uri, response["location"])
        with_auth = uri.host == OAK_API_HOST
        next
      end
      break
    end

    return head :bad_gateway if response.nil?
    return head :bad_gateway if response.is_a?(Net::HTTPRedirection)

    if response.is_a?(Net::HTTPSuccess)
      filename = download_filename_for(type, response)
      ct = effective_content_type(response["Content-Type"].to_s, type)
      send_data response.body,
                filename: filename,
                type: ct,
                disposition: "attachment"
      return
    end

    head :bad_gateway
  end

  def oak_http_get(uri, with_auth:)
    Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", read_timeout: 120, open_timeout: 30) do |http|
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = Oak::ApiClient.authorization_header if with_auth
      http.request(req)
    end
  end

  def resolve_redirect_uri(base_uri, location)
    loc = location.to_s.strip
    return URI(loc) if loc.match?(/\Ahttps?:\/\//i)

    URI.join(base_uri, loc)
  end

  def download_filename_for(type, upstream_response)
    parsed = filename_from_content_disposition(upstream_response["content-disposition"])
    safe = safe_download_basename(parsed)
    return safe if safe.present?

    slug = @lesson.oak_lesson_slug.presence || "lesson-#{@lesson.id}"
    ext = TYPE_EXTENSIONS[type] || "bin"
    "#{slug.to_s.parameterize}-#{type.parameterize}.#{ext}"
  end

  def filename_from_content_disposition(header)
    return nil if header.blank?

    h = header.to_s
    if (m = h.match(/filename\*=(?:UTF-8'')?([^;]+)/i))
      URI.decode_www_form_component(m[1].strip.delete_prefix('"').delete_suffix('"'))
    elsif (m = h.match(/filename="((?:\\.|[^"])*)"/i))
      m[1].gsub('\\"', '"')
    elsif (m = h.match(/filename=([^;\s]+)/i))
      m[1].delete_prefix('"').delete_suffix('"')
    end
  end

  def safe_download_basename(name)
    base = File.basename(name.to_s.strip)
    return nil if base.blank? || base.in?(%w[. ..])

    base.gsub(/[^\p{Word}.\-'\s()\[\]]+/u, "_").truncate(200, omission: "")
  end

  def effective_content_type(upstream, type)
    if upstream.present? && upstream != "application/octet-stream"
      return upstream
    end

    TYPE_CONTENT_TYPES[type] || "application/octet-stream"
  end
end
