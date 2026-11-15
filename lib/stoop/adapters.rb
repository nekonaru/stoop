# frozen_string_literal: true

require_relative 'adapters/base'
require_relative 'adapters/result'
require_relative 'adapters/generic'
require_relative 'adapters/example_shop'

module Stoop
  # Adapter registry. Maps URL hosts to adapter classes; falls back to the
  # generic adapter for everything else.
  module Adapters
    SITE_ADAPTERS = [ExampleShop].freeze

    def self.for_url(url, http_client: nil)
      host = URI.parse(url).host.to_s.downcase
      adapter_class = SITE_ADAPTERS.find { |klass| klass::SITE_DOMAINS.include?(host) }
      (adapter_class || Generic).new(http_client: http_client || HttpClient.new)
    end
  end
end
