# frozen_string_literal: true

require 'sqlite3'
require 'fileutils'
require 'json'
require 'time'

module Stoop
  # SQLite storage. Two tables from the PRD (products, price_points) plus a
  # few bookkeeping columns for failure tracking and notification dedup.
  # All timestamps are ISO8601 UTC.
  class DB
    PRODUCT_COLUMNS = %w[
      id name url target_price drop_percent selector active
      last_notified_at last_notified_price
      consecutive_failures stale stale_notified_at created_at
    ].freeze

    def initialize(path = nil)
      @path = path || ENV.fetch('STOOP_DB') { File.join(Dir.home, '.stoop', 'stoop.db') }
      FileUtils.mkdir_p(File.dirname(@path)) unless @path == ':memory:'
      @db = SQLite3::Database.new(@path)
      @db.results_as_hash = true
      @db.execute('PRAGMA foreign_keys = ON')
      @db.execute('PRAGMA journal_mode = WAL') unless @path == ':memory:'
      migrate!
    end

    def close
      @db.close
    end

    def add_product(name:, url:, target_price: nil, drop_percent: nil, selector: nil)
      @db.execute(
        'INSERT INTO products (name, url, target_price, drop_percent, selector, created_at)
         VALUES (?, ?, ?, ?, ?, ?)',
        [name, url, target_price, drop_percent, selector, now]
      )
      @db.last_insert_row_id
    end

    def find_product(id)
      @db.get_first_row('SELECT * FROM products WHERE id = ?', [id])
    end

    def find_product_by_url(url)
      @db.get_first_row('SELECT * FROM products WHERE url = ?', [url])
    end

    def list_products(active_only: true)
      sql = 'SELECT * FROM products'
      sql += ' WHERE active = 1' if active_only
      sql += ' ORDER BY id'
      @db.execute(sql)
    end

    def update_product(id, **fields)
      allowed = %w[name url target_price drop_percent selector active]
      assignments = fields.select { |k, _| allowed.include?(k.to_s) }
      return 0 if assignments.empty?

      set_clause = assignments.keys.map { |k| "#{k} = ?" }.join(', ')
      @db.execute("UPDATE products SET #{set_clause} WHERE id = ?",
                  assignments.values + [id])
    end

    def delete_product(id)
      @db.execute('DELETE FROM products WHERE id = ?', [id])
      @db.changes
    end

    def set_active(id, active)
      @db.execute('UPDATE products SET active = ? WHERE id = ?', [active ? 1 : 0, id])
      @db.changes
    end

    def record_price_point(product_id:, price:, currency: 'IDR', in_stock: true, checked_at: nil)
      @db.execute(
        'INSERT INTO price_points (product_id, price, currency, in_stock, checked_at)
         VALUES (?, ?, ?, ?, ?)',
        [product_id, price, currency, in_stock ? 1 : 0, checked_at || now]
      )
      @db.last_insert_row_id
    end

    def latest_price_point(product_id, before: nil)
      if before
        @db.get_first_row(
          'SELECT * FROM price_points WHERE product_id = ? AND checked_at < ?
           ORDER BY checked_at DESC, id DESC LIMIT 1',
          [product_id, before]
        )
      else
        @db.get_first_row(
          'SELECT * FROM price_points WHERE product_id = ?
           ORDER BY checked_at DESC, id DESC LIMIT 1',
          [product_id]
        )
      end
    end

    def previous_price_point(product_id)
      @db.get_first_row(
        'SELECT * FROM price_points WHERE product_id = ?
         ORDER BY checked_at DESC, id DESC LIMIT 1 OFFSET 1',
        [product_id]
      )
    end

    def price_history(product_id, limit: nil)
      sql = 'SELECT * FROM price_points WHERE product_id = ? ORDER BY checked_at ASC, id ASC'
      sql += ' LIMIT ?' if limit
      args = [product_id]
      args << limit if limit
      @db.execute(sql, args)
    end

    def record_notification(product_id, price:, at: nil)
      at ||= now
      @db.execute('UPDATE products SET last_notified_at = ?, last_notified_price = ? WHERE id = ?',
                  [at, price, product_id])
    end

    def record_failure(product_id)
      @db.execute('UPDATE products SET consecutive_failures = consecutive_failures + 1 WHERE id = ?', [product_id])
      find_product(product_id)['consecutive_failures']
    end

    def reset_failures(product_id)
      @db.execute('UPDATE products SET consecutive_failures = 0, stale = 0, stale_notified_at = NULL WHERE id = ?',
                  [product_id])
    end

    def mark_stale(product_id, notified_at: nil)
      @db.execute('UPDATE products SET stale = 1, stale_notified_at = COALESCE(?, stale_notified_at) WHERE id = ?',
                  [notified_at, product_id])
    end

    def stale_notified?(product_id)
      !find_product(product_id)['stale_notified_at'].nil?
    end

    def all_price_points
      @db.execute('SELECT price_points.*, products.name AS product_name, products.url AS product_url
                   FROM price_points JOIN products ON products.id = price_points.product_id
                   ORDER BY products.id, price_points.checked_at ASC, price_points.id ASC')
    end

    private

    def now
      Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
    end

    def migrate!
      @db.execute_batch(<<~SQL)
        CREATE TABLE IF NOT EXISTS products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          url TEXT NOT NULL UNIQUE,
          target_price INTEGER,
          drop_percent REAL,
          selector TEXT,
          active INTEGER NOT NULL DEFAULT 1,
          last_notified_at TEXT,
          last_notified_price INTEGER,
          consecutive_failures INTEGER NOT NULL DEFAULT 0,
          stale INTEGER NOT NULL DEFAULT 0,
          stale_notified_at TEXT,
          created_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS price_points (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
          price INTEGER NOT NULL,
          currency TEXT NOT NULL DEFAULT 'IDR',
          in_stock INTEGER NOT NULL DEFAULT 1,
          checked_at TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_price_points_product ON price_points(product_id, checked_at);
      SQL
    end
  end
end
