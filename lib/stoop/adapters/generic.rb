# frozen_string_literal: true

require 'nokogiri'
require 'json'
require_relative '../price_parser'
require_relative '../http_client'
require_relative '../robots'
require_relative 'result'
require_relative 'base'

module Stoop
  module Adapters
    # Generic adapter: extracts product data from a plain HTML page.
    #
    # Extraction order:
    #   1. JSON-LD (`schema.org/Product`), the most reliable source
    #   2. `product:price:amount` / `og:price:amount` meta tags
    #   3. A user-provided CSS selector for the price (per product)
    #
    # Never bypasses anti-bot protection. If robots.txt disallows the URL,
    # raises RobotsDisallowed. If no price can be extracted, raises ParseError.
    class Generic < Base
      JSON_LD_TYPES = %w[product].freeze

      def initialize(http_client: nil, robots: nil)
        super()
        @http_client = http_client || HttpClient.new
        @robots = robots || Robots.new(http_client: @http_client)
      end

      def fetch(url, selector: nil, name_selector: nil, **_options)
        uri = URI.parse(url)
        raise RobotsDisallowed, "robots.txt disallows fetching #{uri.path} for #{uri.host}" unless @robots.allowed?(uri)

        response = @http_client.get(url)
        doc = Nokogiri::HTML(response.body)

        data = from_json_ld(doc) || from_meta(doc) || from_selector(doc, selector)
        raise ParseError, "no price found on #{uri.host}#{uri.path}" if data.nil?

        data[:name] ||= extract_name(doc, name_selector) || uri.host
        Result.new(
          name: data[:name],
          price: data[:price],
          currency: data[:currency] || 'IDR',
          in_stock: data.fetch(:in_stock, true)
        )
      end

      private

      def from_json_ld(doc)
        doc.css('script[type="application/ld+json"]').each do |script|
          parsed = parse_json_safe(script.text)
          next unless parsed

          product = find_product_node(parsed)
          next unless product

          result = extract_from_product(product)
          return result if result
        end
        nil
      end

      def parse_json_safe(text)
        JSON.parse(text)
      rescue JSON::ParserError
        nil
      end

      def find_product_node(node)
        case node
        when Array
          node.each { |child| found = find_product_node(child) and return found }
          nil
        when Hash
          type = node['@type'] || node['type']
          types = [type].flatten.compact.map(&:to_s).map(&:downcase)
          return node if types.intersect?(JSON_LD_TYPES)

          ['@graph', 'itemListElement', 'mainEntity'].each do |key|
            found = find_product_node(node[key]) if node[key]
            return found if found
          end
          nil
        end
      end

      def extract_from_product(product)
        price_raw, currency, in_stock = extract_offer(product['offers'])
        price = PriceParser.parse(price_raw.to_s) if price_raw
        return nil if price.nil?

        name = product['name'] || product['productName']
        { name: name&.to_s&.strip, price: price, currency: currency || 'IDR', in_stock: in_stock }
      end

      def extract_offer(offers)
        offer = [offers].flatten.compact.find { |o| o.is_a?(Hash) }
        return [nil, nil, nil] if offer.nil?

        price_raw = offer['price'] || offer['lowPrice'] || offer.dig('priceSpecification', 'price')
        currency = offer['priceCurrency'] || offer.dig('priceSpecification', 'priceCurrency')
        in_stock = in_stock?(offer['availability'])
        [price_raw, currency, in_stock]
      end

      def in_stock?(availability)
        text = availability.to_s.downcase
        return true if text.empty?
        return false if text.include?('outofstock') || text.include?('soldout') || text.include?('unavailable')

        true
      end

      def from_meta(doc)
        content = ->(selector) { doc.at_css(selector)&.[]('content') }
        price_raw = content.call('meta[property="product:price:amount"]') ||
                    content.call('meta[property="og:price:amount"]') ||
                    content.call('meta[itemprop="price"]') ||
                    doc.at_css('[itemprop="price"]')&.[]('content')
        return nil if price_raw.nil?

        price = PriceParser.parse(price_raw)
        return nil if price.nil?

        currency = content.call('meta[property="product:price:currency"]') ||
                   content.call('meta[property="og:price:currency"]') ||
                   doc.at_css('[itemprop="priceCurrency"]')&.[]('content')
        availability = content.call('meta[property="product:availability"]') || ''
        in_stock = !availability.downcase.include?('out')
        { name: nil, price: price, currency: currency || 'IDR', in_stock: in_stock }
      end

      def from_selector(doc, selector)
        return nil if selector.nil? || selector.empty?

        element = doc.at_css(selector)
        return nil if element.nil?

        price = PriceParser.parse(element.text)
        return nil if price.nil?

        { name: nil, price: price, currency: 'IDR', in_stock: true }
      end

      def extract_name(doc, name_selector)
        if name_selector && !name_selector.empty?
          text = doc.at_css(name_selector)&.text
          return text.strip unless text.nil? || text.strip.empty?
        end

        og_title = doc.at_css('meta[property="og:title"]')&.[]('content')
        return og_title.strip if og_title && !og_title.strip.empty?

        title = doc.at_css('title')&.text
        title&.strip
      end
    end
  end
end
