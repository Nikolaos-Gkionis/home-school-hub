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

    class RateLimited < BadResponse
      attr_reader :retry_after_seconds

      def initialize(message, http_code: 429, retry_after_seconds: nil)
        super(message, http_code: http_code)
        @retry_after_seconds = retry_after_seconds
      end
    end

    # 502/503/504 are brief blips. 429 is handled separately with a long wait.
    RETRY_CODES = [ 502, 503, 504 ].freeze
    MAX_RETRIES = 3
    RATE_LIMIT_RETRIES = 2
    RATE_LIMIT_MAX_WAIT = 180

    class << self
      # After a 429 we stop further HTTP in this process so a sync does not
      # keep punching a locked API (hundreds of extra 429s).
      attr_accessor :cooldown_until

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
        raise_if_cooling_down!(path)

        attempt = 0
        begin
          new.get_json_once(path)
        rescue RateLimited => e
          if attempt < RATE_LIMIT_RETRIES
            attempt += 1
            wait = wait_seconds_for(e, attempt)
            Rails.logger.warn("[Oak::ApiClient] 429 on #{path}; sleeping #{wait}s (#{attempt}/#{RATE_LIMIT_RETRIES})")
            sleep(wait)
            retry
          end
          pause!(wait_seconds_for(e, attempt + 1))
          raise
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

      def parse_retry_after(value)
        return nil if value.blank?
        return value.to_i if value.to_s.match?(/\A\d+\z/)

        (Time.httpdate(value) - Time.now).ceil
      rescue ArgumentError
        nil
      end

      def pause!(seconds)
        wait = [ seconds.to_i, 30 ].max
        self.cooldown_until = Time.now + wait
        Rails.logger.warn("[Oak::ApiClient] cooling down for #{wait}s (until #{cooldown_until})")
      end

      private

      def raise_if_cooling_down!(path)
        return if cooldown_until.nil? || Time.now >= cooldown_until

        remaining = (cooldown_until - Time.now).ceil
        raise RateLimited.new(
          "Oak API cooling down for #{path}",
          retry_after_seconds: remaining
        )
      end

      def wait_seconds_for(error, attempt)
        header = error.retry_after_seconds.to_i
        backoff = 30 * (2**(attempt - 1))
        [ header, backoff, 30 ].max.clamp(1, RATE_LIMIT_MAX_WAIT)
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
        retry_after = self.class.parse_retry_after(res["Retry-After"])
        raise RateLimited.new("Oak API rate limited for #{path}", retry_after_seconds: retry_after)
      else
        raise BadResponse.new("Oak API #{code} for #{path}: #{body[0, 500]}", http_code: code)
      end
    end
  end
end
