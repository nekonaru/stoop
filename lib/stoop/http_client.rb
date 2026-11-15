# frozen_string_literal: true

require 'faraday'
require 'uri'
require_relative 'version'

module Stoop
  # HTTP client with an honest User-Agent, timeouts, per-host rate limiting,
  # and retry with backoff for transient failures.
  #
  # Network errors and 5xx responses are retried up to +max_retries+ times
  # with exponential backoff (1s, 2s, 4s, ...). 4xx responses are not
  # retried. The sleeper and rate limiter are injectable for tests.
  class HttpClient
    DEFAULT_MAX_RETRIES = 3
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    USER_AGENT = "Stoop/#{Stoop::VERSION} (+https://github.com/nekonaru/stoop)".freeze

    Response = Struct.new(:status, :body, :headers)

    def initialize(rate_limiter: nil, sleeper: nil, max_retries: DEFAULT_MAX_RETRIES)
      @rate_limiter = rate_limiter || RateLimiter.new
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @max_retries = max_retries
      @connections = {}
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
      begin
        attempt += 1
        path = uri.path.to_s.empty? ? '/' : uri.path.to_s
        path += "?#{uri.query}" if uri.respond_to?(:query) && uri.query
        raw = connection(uri).get(path)
        if raw.status >= 500 && attempt <= @max_retries
          @sleeper.call(2**(attempt - 1))
          raise Retryable, 'retryable response'
        end

        Response.new(raw.status, raw.body.to_s, raw.headers)
      rescue Retryable
        retry
      rescue Faraday::Error, SocketError, SystemCallError => e
        if attempt <= @max_retries
          @sleeper.call(2**(attempt - 1))
          retry
        end

        raise Adapters::HttpError, "request failed after #{attempt} attempts: #{e.message}"
      end
    end

    def connection(uri)
      @connections[uri.host] ||= Faraday.new(url: base_url(uri)) do |f|
        f.headers['User-Agent'] = USER_AGENT
        f.headers['Accept'] = 'text/html,application/xhtml+xml'
        f.options.open_timeout = OPEN_TIMEOUT
        f.options.timeout = READ_TIMEOUT
      end
    end

    def base_url(uri)
      default_port = uri.scheme == 'https' ? 443 : 80
      port = uri.port && uri.port != default_port ? ":#{uri.port}" : ''
      "#{uri.scheme}://#{uri.host}#{port}"
    end
  end

  # Internal control-flow marker for the retry loop.
  class Retryable < StandardError; end
end
