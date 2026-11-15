# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'uri'
require_relative 'version'

module Stoop
  # HTTP client with an honest User-Agent, timeouts, per-host rate limiting,
  # retry with backoff for transient failures, and a hard cap on response
  # bodies. Bodies larger than MAX_BODY_BYTES abort the download.
  #
  # Network errors and 5xx responses are retried up to +max_retries+ times
  # with exponential backoff (1s, 2s, 4s, ...). 4xx responses are not
  # retried. The sleeper and rate limiter are injectable for tests.
  class HttpClient
    DEFAULT_MAX_RETRIES = 3
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    MAX_BODY_BYTES = 10 * 1024 * 1024 # 10 MB
    USER_AGENT = "Stoop/#{Stoop::VERSION} (+https://github.com/nekonaru/stoop)".freeze

    Response = Struct.new(:status, :body, :headers)

    # Internal marker raised when a body exceeds the cap mid-download.
    class BodyTooLarge < StandardError; end

    def initialize(rate_limiter: nil, sleeper: nil, max_retries: DEFAULT_MAX_RETRIES, user_agent: nil)
      @rate_limiter = rate_limiter || RateLimiter.new
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @max_retries = max_retries
      @user_agent = user_agent || USER_AGENT
    end

    # GETs the URL and returns a Response for 2xx. Raises Adapters::HttpError
    # otherwise.
    def get(url)
      uri = URI.parse(url)
      response = fetch_with_retry(uri)
      return response if response.status.between?(200, 299)

      raise Adapters::HttpError.new("unexpected HTTP #{response.status} for #{uri.host}", status: response.status)
    end

    # Same as get, but returns the response for any status instead of
    # raising. Used by the robots.txt check, which must tolerate error pages.
    def get_response(uri)
      fetch_with_retry(uri)
    rescue Adapters::HttpError
      Response.new(0, '', {})
    end

    private

    def fetch_with_retry(uri)
      @rate_limiter.wait_for(uri.host)

      attempt = 0
      loop do
        attempt += 1
        begin
          response = download(uri)
          return response unless response.status >= 500 && attempt <= @max_retries
        rescue BodyTooLarge
          raise Adapters::HttpError, "response too large (over #{MAX_BODY_BYTES / (1024 * 1024)} MB)"
        rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, EOFError, OpenSSL::SSL::SSLError => e
          raise Adapters::HttpError, "request failed after #{attempt} attempts: #{e.message}" if attempt > @max_retries
        end

        @sleeper.call(2**(attempt - 1))
      end
    end

    def download(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.max_retries = 0

      request = Net::HTTP::Get.new(path(uri))
      request['User-Agent'] = @user_agent
      request['Accept'] = 'text/html,application/xhtml+xml'

      body = +''
      status = nil
      headers = {}
      http.request(request) do |response|
        status = response.code.to_i
        response.each_header { |key, value| headers[key] = value }
        response.read_body do |chunk|
          body << chunk
          raise BodyTooLarge if body.bytesize > MAX_BODY_BYTES
        end
      end

      Response.new(status, body, headers)
    end

    def path(uri)
      base = uri.path.to_s.empty? ? '/' : uri.path.to_s
      uri.query ? "#{base}?#{uri.query}" : base
    end
  end
end
