# frozen_string_literal: true

require_relative 'generic'

module Stoop
  module Adapters
    # Example of a site-specific adapter. Use this as a starting point when a
    # site needs more than the generic extraction (for example a custom API
    # endpoint or a different price location).
    #
    # A site adapter:
    #   1. subclass Generic (or Base for full control),
    #   2. override fetch (or only the private extractors),
    #   3. list the hostnames it handles in SITE_DOMAINS,
    #   4. register itself in lib/stoop/adapters.rb.
    #
    # This example serves the fictional example-shop.com: it reuses the JSON-LD
    # extraction and only narrows the price parsing to whole rupiah, which is
    # all a real shop integration should need.
    class ExampleShop < Generic
      SITE_DOMAINS = %w[example-shop.com www.example-shop.com].freeze

      # Fetches the product page and returns name, price, currency, in_stock.
      # Falls back to the selector extraction when JSON-LD and meta tags are
      # absent, using the shop's known price element.
      def fetch(url, selector: '.product-price', **options)
        super
      end
    end
  end
end
