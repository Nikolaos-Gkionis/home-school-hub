# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Oak
  # HTTP client for https://open-api.thenational.academy/api/v0
  # Request a free key: https://open-api.thenational.academy/docs
  class ApiClient
    BASE = "https://open-api.thenational.academy/api/v0"

    class Error < StandardError; end
    class Unauthorized < Error; end
    class BadResponse < Error; end

    class << self
      def configured?
        token.present?
      end

      def token
        ENV["OAK_API_TOKEN"].presence
      end

      # Full Authorization header value, e.g. "Bearer <token>".
      def authorization_header
        ENV["OAK_API_AUTH_HEADER"].presence || "Bearer #{token}"
      end

      def get_json(path)
        new.get_json(path)
      end
    end

    def get_json(path)
      uri = URI(BASE + path)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120) do |http|
        req = Net::HTTP::Get.new(uri)
        req["Authorization"] = self.class.authorization_header
        req["Accept"] = "application/json"
        res = http.request(req)
        handle_response!(res, path)
      end
    end

    private

    def handle_response!(res, path)
      body = res.body.to_s
      case res.code.to_i
      when 200, 201
        return {} if body.blank?

        JSON.parse(body)
      when 401
        raise Unauthorized, "Oak API unauthorized (check OAK_API_TOKEN / OAK_API_AUTH_HEADER). Path: #{path}"
      else
        raise BadResponse, "Oak API #{res.code} for #{path}: #{body[0, 500]}"
      end
    end
  end
end
