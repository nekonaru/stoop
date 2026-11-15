# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'stoop/adapters'

RSpec.describe Stoop::Adapters::Generic do
  subject(:adapter) do
    sleeper = ->(_seconds) {}
    rate_limiter = Stoop::RateLimiter.new(min_interval: 0, sleeper: sleeper)
    http = Stoop::HttpClient.new(rate_limiter: rate_limiter, sleeper: sleeper, max_retries: 0)
    described_class.new(http_client: http)
  end

  let(:fixtures) { File.expand_path('../../fixtures', __dir__) }
  let(:base_url) { 'https://shop.example.com/item/1' }

  before do
    stub_request(:get, 'https://shop.example.com/robots.txt').to_return(status: 404, body: '')
  end

  def stub_page(path, fixture, status: 200)
    stub_request(:get, "https://shop.example.com#{path}")
      .to_return(status: status, body: File.read(File.join(fixtures, fixture)),
                 headers: { 'Content-Type' => 'text/html; charset=utf-8' })
  end

  it 'extracts name, price, currency and stock from JSON-LD' do
    stub_page('/jsonld', 'product_jsonld.html')
    result = adapter.fetch('https://shop.example.com/jsonld')
    expect(result.name).to eq('Sepatu Lari ExampleShop')
    expect(result.price).to eq(249_000)
    expect(result.currency).to eq('IDR')
    expect(result.in_stock).to be(true)
  end

  it 'handles an offers array and reads the first offer' do
    stub_page('/array', 'product_jsonld_array_offers.html')
    result = adapter.fetch('https://shop.example.com/array')
    expect(result.price).to eq(12_500)
    expect(result.in_stock).to be(true)
  end

  it 'falls back to product meta tags' do
    stub_page('/meta', 'product_meta.html')
    result = adapter.fetch('https://shop.example.com/meta')
    expect(result.name).to eq('Tas Kulit ExampleShop')
    expect(result.price).to eq(1_250_000)
    expect(result.currency).to eq('IDR')
  end

  it 'falls back to the user-provided CSS selector' do
    stub_page('/selector', 'product_selector.html')
    result = adapter.fetch('https://shop.example.com/selector', selector: '.price')
    expect(result.price).to eq(750_000)
    expect(result.name).to eq('Jam Tangan ExampleShop')
  end

  it 'raises ParseError when no price is found' do
    stub_page('/none', 'product_no_price.html')
    expect { adapter.fetch('https://shop.example.com/none') }
      .to raise_error(Stoop::Adapters::ParseError, /no price/)
  end

  it 'raises HttpError for non-2xx responses' do
    stub_page('/missing', 'product_meta.html', status: 404)
    expect { adapter.fetch('https://shop.example.com/missing') }
      .to raise_error(Stoop::Adapters::HttpError) { |e| expect(e.status).to eq(404) }
  end

  it 'refuses to fetch when robots.txt disallows the path' do
    stub_request(:get, 'https://shop.example.com/robots.txt')
      .to_return(status: 200, body: "User-agent: *\nDisallow: /private\n")
    stub_page('/private/item', 'product_jsonld.html')

    expect { adapter.fetch('https://shop.example.com/private/item') }
      .to raise_error(Stoop::Adapters::RobotsDisallowed)
    expect(a_request(:get, 'https://shop.example.com/private/item')).not_to have_been_made
  end

  it 'parses JSON-LD embedded in a @graph wrapper' do
    html = <<~HTML
      <html><head><script type="application/ld+json">
      {"@context":"https://schema.org","@graph":[{"@type":"BreadcrumbList"},
       {"@type":"Product","name":"Graph Product","offers":{"price":99000,"priceCurrency":"IDR","availability":"https://schema.org/OutOfStock"}}]}
      </script></head><body></body></html>
    HTML
    stub_request(:get, 'https://shop.example.com/graph').to_return(status: 200, body: html)
    result = adapter.fetch('https://shop.example.com/graph')
    expect(result.name).to eq('Graph Product')
    expect(result.price).to eq(99_000)
    expect(result.in_stock).to be(false)
  end
end
