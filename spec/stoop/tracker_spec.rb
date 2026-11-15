# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stoop/tracker'

RSpec.describe Stoop::Tracker do
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'stoop-test.db') }
  let(:db) { Stoop::DB.new(path) }
  let(:config) { Stoop::Config.new.load(path: nil, env: {}) }
  let(:notifier) { instance_double(Stoop::Notifiers::Telegram, deliver: true) }
  let(:adapter) { instance_double(Stoop::Adapters::Generic) }

  subject(:tracker) do
    described_class.new(db: db, config: config, notifier: notifier,
                        adapter_factory: ->(_url) { adapter })
  end

  before do
    ENV['STOOP_DB'] = path
    ENV.delete('TELEGRAM_BOT_TOKEN')
    ENV.delete('TELEGRAM_CHAT_ID')
  end

  after do
    ENV.delete('STOOP_DB')
    db.close
    FileUtils.remove_entry(dir)
  end

  def product_with(target_price: nil, drop_percent: nil)
    id = db.add_product(name: 'Sepatu Test', url: 'https://shop.example.com/1',
                        target_price: target_price, drop_percent: drop_percent)
    db.find_product(id)
  end

  def stub_price(price, in_stock: true)
    allow(adapter).to receive(:fetch).and_return(
      Stoop::Adapters::Result.new(name: 'Sepatu Test', price: price, currency: 'IDR', in_stock: in_stock)
    )
  end

  it 'does not notify when nothing triggers the rules' do
    product_with(target_price: 100)
    stub_price(400_000)
    outcome = tracker.check_product(db.find_product(1))
    expect(outcome.notified).to be(false)
    expect(notifier).not_to have_received(:deliver)
  end

  it 'sends exactly one Telegram message when the target is reached' do
    product_with(target_price: 250_000)
    stub_price(249_000)
    outcome = tracker.check_product(db.find_product(1))
    expect(outcome.notified).to be(true)
    expect(notifier).to have_received(:deliver).once
  end

  it 'applies the cooldown within 12 hours' do
    product_with(target_price: 250_000)
    stub_price(249_000)
    tracker.check_product(db.find_product(1))
    stub_price(240_000) # price falls further, still triggers the rules
    outcome = tracker.check_product(db.find_product(1))
    expect(outcome.notified).to be(false)
    expect(notifier).to have_received(:deliver).once
  end

  it 'never notifies twice for the exact same price' do
    product_with(target_price: 500_000)
    stub_price(249_000)
    tracker.check_product(db.find_product(1))
    product = db.find_product(1)
    db.record_notification(product['id'], price: 249_000,
                                          at: (Time.now.utc - (13 * 3600)).strftime('%Y-%m-%dT%H:%M:%SZ'))
    stub_price(249_000)
    outcome = tracker.check_product(db.find_product(1))
    expect(outcome.notified).to be(false)
    expect(notifier).to have_received(:deliver).once
  end

  it 'notifies again after the cooldown when the price changed' do
    product_with(target_price: 250_000)
    stub_price(249_000)
    tracker.check_product(db.find_product(1))
    product = db.find_product(1)
    db.record_notification(product['id'], price: 249_000,
                                          at: (Time.now.utc - (13 * 3600)).strftime('%Y-%m-%dT%H:%M:%SZ'))
    stub_price(239_000)
    outcome = tracker.check_product(db.find_product(1))
    expect(outcome.notified).to be(true)
  end

  it 'notifies on restock even with the same price' do
    product_with(target_price: nil, drop_percent: 50)
    stub_price(249_000, in_stock: false)
    tracker.check_product(db.find_product(1))
    product = db.find_product(1)
    db.record_notification(product['id'], price: 249_000,
                                          at: (Time.now.utc - (13 * 3600)).strftime('%Y-%m-%dT%H:%M:%SZ'))
    stub_price(249_000, in_stock: true)
    outcome = tracker.check_product(db.find_product(1))
    expect(outcome.notified).to be(true)
  end

  def stub_config(values)
    yaml = File.join(dir, 'config.yml')
    File.write(yaml, values.map { |k, v| "#{k}: #{v}" }.join("\n"))
    Stoop::Config.new.load(path: yaml, env: {})
  end

  it 'records failures and marks the product stale after consecutive errors' do
    product_with
    allow(adapter).to receive(:fetch).and_raise(Stoop::Adapters::HttpError.new('HTTP 503', status: 503))
    stale_config = stub_config('stale_after_failures' => 2)
    stale_tracker = described_class.new(db: db, config: stale_config, notifier: notifier,
                                        adapter_factory: ->(_url) { adapter })
    2.times { stale_tracker.check_product(db.find_product(1)) }
    product = db.find_product(1)
    expect(product['stale']).to eq(1)
    expect(notifier).to have_received(:deliver).once.with(/gagal dipantau/)
  end

  it 'does not notify stale twice for the same episode' do
    product_with
    allow(adapter).to receive(:fetch).and_raise(Stoop::Adapters::HttpError.new('HTTP 503', status: 503))
    stale_config = stub_config('stale_after_failures' => 2)
    stale_tracker = described_class.new(db: db, config: stale_config, notifier: notifier,
                                        adapter_factory: ->(_url) { adapter })
    3.times { stale_tracker.check_product(db.find_product(1)) }
    expect(notifier).to have_received(:deliver).once
  end

  it 'records price points for history' do
    product_with
    stub_price(249_000)
    tracker.check_product(db.find_product(1))
    history = db.price_history(1)
    expect(history.size).to be >= 1
    expect(history.last['price']).to eq(249_000)
  end
end
