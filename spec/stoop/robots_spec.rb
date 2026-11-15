# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'stoop/robots'

RSpec.describe Stoop::Robots do
  subject(:robots) do
    sleeper = ->(_seconds) {}
    http = Stoop::HttpClient.new(rate_limiter: Stoop::RateLimiter.new(min_interval: 0, sleeper: sleeper),
                                 sleeper: sleeper, max_retries: 0)
    described_class.new(http_client: http)
  end

  let(:uri) { URI.parse('https://shop.example.com/products/123') }

  it 'allows fetching when robots.txt does not exist' do
    stub_request(:get, 'https://shop.example.com/robots.txt').to_return(status: 404)
    expect(robots.allowed?(uri)).to be(true)
  end

  it 'allows fetching when robots.txt allows the path' do
    stub_request(:get, 'https://shop.example.com/robots.txt')
      .to_return(status: 200, body: "User-agent: *\nAllow: /products\n")
    expect(robots.allowed?(uri)).to be(true)
  end

  it 'disallows fetching when robots.txt disallows the path' do
    stub_request(:get, 'https://shop.example.com/robots.txt')
      .to_return(status: 200, body: "User-agent: *\nDisallow: /products\n")
    expect(robots.allowed?(uri)).to be(false)
  end

  it 'only matches the disallow prefix, not a substring' do
    stub_request(:get, 'https://shop.example.com/robots.txt')
      .to_return(status: 200, body: "User-agent: *\nDisallow: /private\n")
    expect(robots.allowed?(URI.parse('https://shop.example.com/products/123'))).to be(true)
  end

  it 'respects rules specific to our user agent' do
    stub_request(:get, 'https://shop.example.com/robots.txt')
      .to_return(status: 200, body: "User-agent: Stoop\nDisallow: /\n\nUser-agent: *\nAllow: /\n")
    expect(robots.allowed?(uri)).to be(false)
  end

  it 'ignores disallow rules for other user agents' do
    stub_request(:get, 'https://shop.example.com/robots.txt')
      .to_return(status: 200, body: "User-agent: OtherBot\nDisallow: /\n")
    expect(robots.allowed?(uri)).to be(true)
  end

  it 'allows fetching when robots.txt cannot be fetched' do
    stub_request(:get, 'https://shop.example.com/robots.txt').to_timeout
    expect(robots.allowed?(uri)).to be(true)
  end
end
