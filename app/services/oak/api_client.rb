# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module Oak
  # HTTP client for https://open-api.thenational.academy/api/v0
  # Request a free key: https://open-api.thenational.academy/docs/about-oaks-api/api-overview
  class ApiClient
    BASE = "https://open-api.thenational.academy/api/v0"

    class Error < StandardError; end
    class Unauthorized < Error; end

    class BadResponse < Error
      attr_reader :http_code

      def initialize(message, http_code: nil)
        super(message)
        @http_code = http_code
      end
    end

    class RateLimited < BadResponse; end

    RETRY_CODES = [ 429, 502, 503, 504 ].freeze
    MAX_RETRIES = 3

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

      def get_json(path, retries: MAX_RETRIES)
        attempt = 0
        begin
          new.get_json_once(path)
        rescue BadResponse => e
          if e.http_code.present? && RETRY_CODES.include?(e.http_code) && attempt < retries
            attempt += 1
            sleep(0.35 * (2**attempt))
            retry
          end
          raise
        rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET => e
          if attempt < retries
            attempt += 1
            sleep0 = 0.35 * (2**attempt)
            Rails.logger.warn("[Oak::ApiClient] retry #{path} after #{e.class}: sleep #{sleep0}s")
            sleep(sleep0)
            retry
          end
          raise BadResponse.new("Oak API timeout for #{path}: #{e.message}", http_code: nil)
        end
      end
    end

    def get_json_once(path)
      uri = URI(BASE + path)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 120, open_timeout: 30) do |http|
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
      code = res.code.to_i
      case code
      when 200, 201
        return {} if body.blank?

        JSON.parse(body)
      when 401
        raise Unauthorized, "Oak API unauthorized (check OAK_API_TOKEN / OAK_API_AUTH_HEADER). Path: #{path}"
      when 429
        raise RateLimited.new("Oak API rate limited for #{path}", http_code: code)
      else
        raise BadResponse.new("Oak API #{code} for #{path}: #{body[0, 500]}", http_code: code)
      end
    end
  end
end
