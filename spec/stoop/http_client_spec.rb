# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'
require 'stoop/http_client'
require 'stoop/adapters/result'

RSpec.describe Stoop::HttpClient do
  subject(:client) do
    sleeper = ->(seconds) { slept << seconds }
    rate_limiter = Stoop::RateLimiter.new(min_interval: 0, sleeper: sleeper)
    described_class.new(rate_limiter: rate_limiter, sleeper: sleeper, max_retries: 2)
  end

  let(:slept) { [] }

  it 'returns a response for a 2xx' do
    stub_request(:get, 'https://shop.example.com/item').to_return(status: 200, body: 'ok')
    response = client.get('https://shop.example.com/item')
    expect(response.status).to eq(200)
    expect(response.body).to eq('ok')
  end

  it 'raises HttpError for non-2xx without retrying 4xx' do
    stub_request(:get, 'https://shop.example.com/missing').to_return(status: 404, body: 'nope')
    expect { client.get('https://shop.example.com/missing') }
      .to raise_error(Stoop::Adapters::HttpError) { |e| expect(e.status).to eq(404) }
    expect(a_request(:get, 'https://shop.example.com/missing')).to have_been_made.once
  end

  it 'retries 5xx with backoff and then raises' do
    stub_request(:get, 'https://shop.example.com/broken').to_return(status: 503, body: 'no')
    expect { client.get('https://shop.example.com/broken') }
      .to raise_error(Stoop::Adapters::HttpError, /503|retries/)
    expect(a_request(:get, 'https://shop.example.com/broken')).to have_been_made.times(3)
    expect(slept).to eq([1, 2])
  end

  it 'retries network errors and eventually succeeds' do
    stub_request(:get, 'https://shop.example.com/flaky').to_timeout.then.to_return(status: 200, body: 'ok')
    response = client.get('https://shop.example.com/flaky')
    expect(response.status).to eq(200)
    expect(a_request(:get, 'https://shop.example.com/flaky')).to have_been_made.twice
  end

  it 'sends an honest User-Agent header' do
    stub_request(:get, 'https://shop.example.com/ua').to_return(status: 200, body: '')
    client.get('https://shop.example.com/ua')
    expect(a_request(:get, 'https://shop.example.com/ua')
      .with(headers: { 'User-Agent' => %r{Stoop/#{Stoop::VERSION}} })).to have_been_made
  end
end
