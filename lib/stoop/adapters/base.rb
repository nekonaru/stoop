# frozen_string_literal: true

module Stoop
  module Adapters
    # Base class for site adapters. Subclasses implement +fetch(url, **options)+
    # and return an Adapters::Result.
    class Base
      # Fetches and parses the given URL.
      #
      # Returns Adapters::Result on success. Raises HttpError, ParseError,
      # or RobotsDisallowed on failure.
      def fetch(url, **_options)
        raise NotImplementedError, "#{self.class} must implement #fetch"
      end
    end
  end
end
