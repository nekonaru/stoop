# frozen_string_literal: true

module Stoop
  # Simple per-host rate limiter. Keeps one monotonic timestamp per host and
  # sleeps just long enough to satisfy the minimum interval. Injectable clock
  # and sleeper make it testable and slow-free in tests.
  class RateLimiter
    DEFAULT_MIN_INTERVAL = 5.0 # seconds between requests to the same host

    def initialize(min_interval: DEFAULT_MIN_INTERVAL, clock: nil, sleeper: nil)
      @min_interval = min_interval
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @last_request_at = {}
    end

    def wait_for(host)
      now = @clock.call
      last = @last_request_at[host]
      @sleeper.call(@min_interval - (now - last)) if last && (now - last) < @min_interval
      @last_request_at[host] = @clock.call
    end
  end
end
