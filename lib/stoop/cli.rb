# frozen_string_literal: true

require 'thor'
require 'time'
require 'uri'
require_relative 'version'
require_relative 'db'
require_relative 'config'
require_relative 'adapters'
require_relative 'tracker'

module Stoop
  # Command line interface for Stoop.
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'version', 'Print the Stoop version'
    def version
      puts "Stoop #{VERSION}"
    end

    map %w[-v --version] => :version

    desc 'add URL', 'Add a product URL to the watchlist'
    option :target, type: :numeric, desc: 'Target price in rupiah'
    option :drop_percent, type: :numeric, desc: 'Notify when the price drops by this percent'
    option :selector, type: :string, desc: 'CSS selector for the price element'
    option :name, type: :string, desc: 'Product name (fetched from the page when omitted)'
    def add(url)
      uri = parse_url(url)
      fail_with("URL must use http or https: #{url}") unless %w[http https].include?(uri.scheme)

      name = options[:name] || fetch_name(uri.to_s) || uri.to_s

      id = db.add_product(name: name, url: uri.to_s,
                          target_price: options[:target]&.to_i,
                          drop_percent: options[:drop_percent]&.to_f,
                          selector: options[:selector])
      report_added(id, name, uri, options[:target])
    rescue SQLite3::ConstraintException
      existing = db.find_product_by_url(uri.to_s)
      fail_with("already in watchlist as ##{existing['id']}: #{existing['name']}")
    end

    desc 'list', 'List watchlist products'
    option :all, type: :boolean, default: false, desc: 'Include inactive products'
    def list
      products = db.list_products(active_only: !options[:all])
      fail_with('Watchlist is empty. Add one with: stoop add <url> --target 250000') if products.empty?

      rows = products.map do |product|
        latest = db.latest_price_point(product['id'])
        price = latest ? format_price(latest['price']) : '(no data)'
        target = product['target_price'] ? format_price(product['target_price']) : '-'
        drop = product['drop_percent'] ? "#{product['drop_percent']}%" : '-'
        active = product['active'] == 1 ? 'yes' : 'no'
        [product['id'], truncate(product['name'], 40), price, target, drop, active, truncate(product['url'], 60)]
      end
      print_table(%w[ID Name Price Target Drop Active URL], rows)
    end

    desc 'remove ID', 'Remove a product from the watchlist'
    def remove(id)
      product = find_product_or_fail(id)
      db.delete_product(product['id'])
      puts "Removed product ##{product['id']}: #{product['name']}"
    end

    desc 'check [ID]', 'Check current prices (all active products, or one ID)'
    def check(id = nil)
      products = if id
                   [find_product_or_fail(id)]
                 else
                   db.list_products
                 end
      fail_with('Watchlist is empty. Add one with: stoop add <url> --target 250000') if products.empty?

      unless config.telegram_configured?
        warn 'Telegram belum dikonfigurasi (TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID); notifikasi dilewati.'
      end

      tracker = Stoop::Tracker.new(db: db, config: config)
      outcomes = tracker.check_all(id: id)
      failures = 0
      outcomes.each do |outcome|
        report_outcome(outcome)
        failures += 1 if outcome.error
      end
      exit(failures.positive? ? 1 : 0)
    end

    desc 'history ID', 'Show price history for a product'
    option :limit, type: :numeric, desc: 'Limit the number of points shown'
    def history(id)
      product = find_product_or_fail(id)
      points = db.price_history(product['id'], limit: options[:limit])
      fail_with("No price history for product ##{product['id']} yet. Run: stoop check") if points.empty?

      puts product['name']
      puts product['url']
      rows = []
      previous = nil
      points.each do |point|
        change = percent_change(previous, point['price'])
        rows << [format_time(point['checked_at']), format_price(point['price']), point['currency'],
                 point['in_stock'] == 1 ? 'yes' : 'NO', change]
        previous = point['price']
      end
      print_table(%w[Checked Price Cur Stock Change], rows)
    end

    no_commands do
      def db
        @db ||= DB.new(config.database_path)
      end

      def config
        @config ||= Config.load
      end

      def report_added(id, name, uri, target)
        puts "Added product ##{id}: #{name}"
        puts "  URL: #{uri}"
        puts "  Target: #{target ? format_price(target.to_i) : '(not set)'}"
      end

      def report_outcome(outcome)
        if outcome.error
          warn "  gagal: #{outcome.error}"
          return
        end

        change = percent_change(outcome.previous_price, outcome.price)
        suffix = outcome.notified ? ', notif terkirim' : ''
        puts "##{outcome.product_id} #{truncate(outcome.name, 40)}: #{format_price(outcome.price)} (#{change}#{suffix})"
      end

      def fetch_name(url)
        Adapters.for_url(url).fetch(url).name
      rescue StandardError
        nil
      end

      def parse_url(url)
        URI.parse(url)
      rescue URI::InvalidURIError
        fail_with("invalid URL: #{url}")
      end

      def find_product_or_fail(id)
        integer = Integer(id, exception: false)
        fail_with("invalid ID: #{id}") if integer.nil?

        product = db.find_product(integer)
        fail_with("no product with ID #{integer}") if product.nil?

        product
      end

      def fail_with(message)
        warn message
        exit(1)
      end

      def format_price(value)
        "Rp #{value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1.').reverse}"
      end

      def format_time(iso8601)
        Time.parse(iso8601).localtime.strftime('%Y-%m-%d %H:%M')
      rescue ArgumentError
        iso8601
      end

      def percent_change(previous, current)
        return '-' if previous.nil? || previous.zero?

        change = ((current - previous).to_f / previous) * 100
        format('%+.1f%%', change)
      end

      def truncate(text, length)
        text = text.to_s
        text.length > length ? "#{text[0, length - 3]}..." : text
      end

      def print_table(headers, rows)
        widths = ([headers] + rows).transpose.map { |column| column.map { |cell| cell.to_s.length }.max }
        puts headers.map.with_index { |header, i| header.ljust(widths[i]) }.join('  ').rstrip
        puts widths.map { |width| '-' * width }.join('  ')
        rows.each do |row|
          puts row.map.with_index { |cell, i| cell.to_s.ljust(widths[i]) }.join('  ').rstrip
        end
      end
    end
  end
end
