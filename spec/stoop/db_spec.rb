# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stoop/db'

RSpec.describe Stoop::DB do
  subject(:db) { described_class.new(path) }

  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'stoop-test.db') }

  after do
    db.close
    FileUtils.remove_entry(dir)
  end

  it 'creates the schema on first use' do
    row = db.instance_variable_get(:@db)
            .get_first_row("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    expect(row['name']).to eq('price_points')
  end

  describe 'products' do
    it 'adds and finds a product' do
      id = db.add_product(name: 'Test Product', url: 'https://shop.example.com/item',
                          target_price: 250_000, drop_percent: 10)
      product = db.find_product(id)
      expect(product['name']).to eq('Test Product')
      expect(product['target_price']).to eq(250_000)
      expect(product['active']).to eq(1)
      expect(product['consecutive_failures']).to eq(0)
    end

    it 'rejects duplicate URLs' do
      db.add_product(name: 'One', url: 'https://shop.example.com/dup')
      expect { db.add_product(name: 'Two', url: 'https://shop.example.com/dup') }
        .to raise_error(SQLite3::ConstraintException)
    end

    it 'lists active products in id order' do
      db.add_product(name: 'A', url: 'https://shop.example.com/a')
      db.add_product(name: 'B', url: 'https://shop.example.com/b')
      names = db.list_products.map { |p| p['name'] }
      expect(names).to eq(%w[A B])
    end

    it 'soft-removes a product by marking it inactive' do
      id = db.add_product(name: 'A', url: 'https://shop.example.com/a')
      db.set_active(id, false)
      expect(db.list_products.map { |p| p['id'] }).to be_empty
      expect(db.list_products(active_only: false).map { |p| p['id'] }).to eq([id])
    end

    it 'deletes a product and its price points' do
      id = db.add_product(name: 'A', url: 'https://shop.example.com/a')
      db.record_price_point(product_id: id, price: 100_000)
      expect(db.delete_product(id)).to eq(1)
      expect(db.price_history(id)).to be_empty
    end
  end

  describe 'price points' do
    let!(:product_id) { db.add_product(name: 'A', url: 'https://shop.example.com/a') }

    it 'records and reads back a price point' do
      db.record_price_point(product_id: product_id, price: 123_000, currency: 'IDR', in_stock: true)
      point = db.latest_price_point(product_id)
      expect(point['price']).to eq(123_000)
      expect(point['in_stock']).to eq(1)
    end

    it 'returns history in chronological order' do
      db.record_price_point(product_id: product_id, price: 100_000, checked_at: '2026-01-01T00:00:00Z')
      db.record_price_point(product_id: product_id, price: 90_000, checked_at: '2026-01-02T00:00:00Z')
      prices = db.price_history(product_id).map { |p| p['price'] }
      expect(prices).to eq([100_000, 90_000])
    end

    it 'finds the previous price point' do
      db.record_price_point(product_id: product_id, price: 100_000, checked_at: '2026-01-01T00:00:00Z')
      db.record_price_point(product_id: product_id, price: 90_000, checked_at: '2026-01-02T00:00:00Z')
      expect(db.previous_price_point(product_id)['price']).to eq(100_000)
    end

    it 'finds the latest point before a timestamp' do
      db.record_price_point(product_id: product_id, price: 100_000, checked_at: '2026-01-01T00:00:00Z')
      db.record_price_point(product_id: product_id, price: 90_000, checked_at: '2026-01-02T00:00:00Z')
      before = db.latest_price_point(product_id, before: '2026-01-02T00:00:00Z')
      expect(before['price']).to eq(100_000)
    end
  end

  describe 'failure tracking' do
    let!(:product_id) { db.add_product(name: 'A', url: 'https://shop.example.com/a') }

    it 'increments and resets consecutive failures' do
      expect(db.record_failure(product_id)).to eq(1)
      expect(db.record_failure(product_id)).to eq(2)
      db.reset_failures(product_id)
      expect(db.find_product(product_id)['consecutive_failures']).to eq(0)
    end

    it 'marks and reports stale' do
      db.mark_stale(product_id, notified_at: '2026-01-01T00:00:00Z')
      expect(db.find_product(product_id)['stale']).to eq(1)
      expect(db.stale_notified?(product_id)).to be(true)
    end
  end

  describe 'notifications' do
    let!(:product_id) { db.add_product(name: 'A', url: 'https://shop.example.com/a') }

    it 'records notification state' do
      db.record_notification(product_id, price: 249_000, at: '2026-01-01T00:00:00Z')
      product = db.find_product(product_id)
      expect(product['last_notified_at']).to eq('2026-01-01T00:00:00Z')
      expect(product['last_notified_price']).to eq(249_000)
    end
  end
end
