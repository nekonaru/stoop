# frozen_string_literal: true

module Stoop
  module Adapters
    # Outcome of a successful product fetch.
    Result = Struct.new(:name, :price, :currency, :in_stock, keyword_init: true) do
      def initialize(name:, price:, currency: 'IDR', in_stock: true)
        super
      end
    end

    # Base class for adapter errors.
    class Error < StandardError; end

    # The page could not be fetched (network error, non-2xx response).
    class HttpError < Error
      attr_reader :status

      def initialize(message, status: nil)
        @status = status
        super(message)
      end
    end

    # The page was fetched but no price could be extracted.
    class ParseError < Error; end

    # robots.txt disallows fetching this URL for our user agent.
    class RobotsDisallowed < Error; end
  end
end
