# frozen_string_literal: true

# Security-relevant invariants, as executable tests.
# Each test maps to a property the release gate depends on.
require 'spec_helper'
require 'webmock/rspec'
require 'tmpdir'
require 'stoop/cli'

RSpec.describe 'Security invariants' do
  let(:dir) { Dir.mktmpdir }
  let(:db_path) { File.join(dir, 'stoop-test.db') }
  let(:fixtures) { File.expand_path('fixtures', __dir__) }

  before do
    ENV['STOOP_DB'] = db_path
  end

  after do
    ENV.delete('STOOP_DB')
    ObjectSpace.each_object(Stoop::DB) do |db|
      db.close
    rescue StandardError
      nil
    end
    FileUtils.remove_entry(dir)
  end

  it 'does not execute SQL from an untrusted product name' do
    db = Stoop::DB.new(db_path)
    hostile = "x'); DROP TABLE products; --"
    id = db.add_product(name: hostile, url: 'https://shop.example.com/1')
    db.record_price_point(product_id: id, price: 100_000)
    expect(db.find_product(id)['name']).to eq(hostile)
    expect(db.list_products.size).to eq(1)
    db.close
  end

  it 'stores price points with quotes and script tags unchanged' do
    db = Stoop::DB.new(db_path)
    id = db.add_product(name: "<script>alert('x')</script> \"quoted\"", url: 'https://shop.example.com/1')
    expect(db.find_product(id)['name']).to include('<script>')
    db.close
  end

  it 'rejects non-http(s) URLs before any request is made' do
    stub_request(:any, /.*/)
    expect { Stoop::CLI.start(['add', 'javascript:alert(1)']) }
      .to raise_error(SystemExit).and output(/http or https|invalid/).to_stderr
    expect(a_request(:any, /.*/)).not_to have_been_made
  end

  it 'refuses to parse an oversized response body' do
    stub_request(:get, 'https://shop.example.com/huge')
      .to_return(status: 200, body: 'x' * ((10 * 1024 * 1024) + 1))
    stub_request(:get, 'https://shop.example.com/robots.txt').to_return(status: 404)

    sleeper = ->(_seconds) {}
    http = Stoop::HttpClient.new(rate_limiter: Stoop::RateLimiter.new(min_interval: 0, sleeper: sleeper),
                                 sleeper: sleeper, max_retries: 0)
    adapter = Stoop::Adapters::Generic.new(http_client: http)
    expect { adapter.fetch('https://shop.example.com/huge') }
      .to raise_error(Stoop::Adapters::HttpError, /too large/)
  end

  it 'treats robots.txt disallow as a hard stop before fetching' do
    stub_request(:get, 'https://shop.example.com/robots.txt')
      .to_return(status: 200, body: "User-agent: *\nDisallow: /")
    sleeper = ->(_seconds) {}
    http = Stoop::HttpClient.new(rate_limiter: Stoop::RateLimiter.new(min_interval: 0, sleeper: sleeper),
                                 sleeper: sleeper, max_retries: 0)
    adapter = Stoop::Adapters::Generic.new(http_client: http)
    expect { adapter.fetch('https://shop.example.com/item') }
      .to raise_error(Stoop::Adapters::RobotsDisallowed)
    expect(a_request(:get, 'https://shop.example.com/item')).not_to have_been_made
  end

  it 'raises a friendly error for a config file with YAML aliases' do
    config_path = File.join(dir, 'config.yml')
    File.write(config_path, "a: &x value\nb: *x\n")
    expect { Stoop::Config.new.load(path: config_path, env: {}) }
      .to raise_error(ArgumentError, /config file/)
  end

  it 'raises a friendly error for a config file that is not a mapping' do
    config_path = File.join(dir, 'config.yml')
    File.write(config_path, "- just\n- a\n- list\n")
    expect { Stoop::Config.new.load(path: config_path, env: {}) }
      .to raise_error(ArgumentError, /YAML mapping/)
  end

  it 'keeps error messages free of the Telegram token' do
    stub_request(:post, 'https://api.telegram.org/botsecret-token/sendMessage').to_return(
      status: 500, body: '{"ok":false,"description":"Internal"}',
      headers: { 'Content-Type' => 'application/json' }
    )
    notifier = Stoop::Notifiers::Telegram.new(bot_token: 'secret-token', chat_id: '42')
    expect { notifier.deliver('hi') }
      .to raise_error(Stoop::Notifiers::NotifierError) { |e| expect(e.message).not_to include('secret-token') }
  end

  it 'loads ~/.stoop/.env values into the process env without printing them' do
    stoop_dir = File.join(dir, '.stoop')
    FileUtils.mkdir_p(stoop_dir)
    File.write(File.join(stoop_dir, '.env'), "TELEGRAM_BOT_TOKEN=leakme-123\n")
    allow(Dir).to receive(:home).and_return(dir)
    env = {}
    out = StringIO.new
    orig = $stderr
    $stderr = out
    Stoop::Config.new.load(path: nil, env: env)
    $stderr = orig
    expect(env['TELEGRAM_BOT_TOKEN']).to eq('leakme-123')
    expect(out.string).to eq('')
  end
end
