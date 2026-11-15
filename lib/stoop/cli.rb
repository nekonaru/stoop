# frozen_string_literal: true

require 'thor'
require 'time'
require 'uri'
require_relative 'version'
require_relative 'format'
require_relative 'db'
require_relative 'config'
require_relative 'adapters'
require_relative 'tracker'

module Stoop
  # Command line interface for Stoop.
  class CLI < Thor
    # Thor reserves `run` defensively. This CLI does not include Thor::Actions,
    # so defining the `run` command is safe.
    # rubocop:disable-next Naming/PredicatePrefix
    def self.is_thor_reserved_word?(word, type)
      return false if word == 'run' && type == :command

      super
    end

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
        price = latest ? Format.price(latest['price']) : '(no data)'
        target = product['target_price'] ? Format.price(product['target_price']) : '-'
        drop = product['drop_percent'] ? "#{product['drop_percent']}%" : '-'
        active = product['active'] == 1 ? 'yes' : 'no'
        [product['id'], Format.truncate(product['name'], 40), price, target, drop, active,
         Format.truncate(product['url'], 60)]
      end
      puts Format.table(%w[ID Name Price Target Drop Active URL], rows)
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

    desc 'run', 'Run the watch loop in the foreground (Ctrl+C stops)'
    option :once, type: :boolean, default: false, desc: 'Run a single check cycle and exit'
    def run
      interval = config.check_interval_minutes
      if interval < 30
        warn 'Interval di bawah 30 menit tidak diizinkan; dipakai 30 menit.'
        interval = 30
      end

      tracker = Stoop::Tracker.new(db: db, config: config)

      unless config.telegram_configured?
        warn 'Telegram belum dikonfigurasi (TELEGRAM_BOT_TOKEN/TELEGRAM_CHAT_ID); notifikasi dilewati.'
      end

      if options[:once]
        log_cycle(tracker)
        return
      end

      warn "Stoop #{VERSION}: memantau setiap #{interval} menit. Ctrl+C untuk berhenti."
      log_cycle(tracker)

      require 'rufus-scheduler'
      scheduler = Rufus::Scheduler.new
      scheduler.every("#{interval}m") { log_cycle(tracker) }
      stop = -> { scheduler.shutdown(:wait) }
      trap('INT', &stop)
      trap('TERM', &stop)
      scheduler.join
    end

    desc 'export [ID]', 'Export price history as CSV (stdout, or --output FILE)'
    option :output, type: :string, desc: 'Write the CSV to FILE instead of stdout'
    def export(id = nil)
      product_id = nil
      if id
        product = find_product_or_fail(id)
        product_id = product['id']
      end

      rows = [%w[product_id name url checked_at price currency in_stock]]
      db.all_price_points(product_id: product_id).each do |row|
        rows << [row['product_id'], row['product_name'], row['product_url'],
                 row['checked_at'], row['price'], row['currency'], row['in_stock'] == 1 ? 'true' : 'false']
      end

      csv = rows.map { |row| Format.csv_row(row) }.join

      if options[:output]
        File.write(options[:output], csv)
        puts "Exported #{csv.lines.length - 1} rows to #{options[:output]}"
      else
        print csv
      end
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
        change = Format.percent_change(previous, point['price'])
        rows << [Format.time(point['checked_at']), Format.price(point['price']), point['currency'],
                 point['in_stock'] == 1 ? 'yes' : 'NO', change]
        previous = point['price']
      end
      puts Format.table(%w[Checked Price Cur Stock Change], rows)
    end

    no_commands do
      def db
        @db ||= DB.new(config.database_path)
      end

      def config
        @config ||= Config.load
      end

      def log_cycle(tracker)
        timestamp = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
        outcomes = tracker.check_all
        outcomes.each { |outcome| log_outcome(timestamp, outcome) }
        puts "[#{timestamp}] cycle complete: #{outcomes.size} products"
      end

      def log_outcome(timestamp, outcome)
        if outcome.error
          warn "[#{timestamp}] ##{outcome.product_id} #{outcome.name}: gagal: #{outcome.error}"
          return
        end

        suffix = outcome.notified ? ', notif terkirim' : ''
        puts "[#{timestamp}] ##{outcome.product_id} #{outcome.name}: #{Format.price(outcome.price)}#{suffix}"
      end

      def report_added(id, name, uri, target)
        puts "Added product ##{id}: #{name}"
        puts "  URL: #{uri}"
        puts "  Target: #{target ? Format.price(target.to_i) : '(not set)'}"
      end

      def report_outcome(outcome)
        if outcome.error
          warn "  gagal: #{outcome.error}"
          return
        end

        change = Format.percent_change(outcome.previous_price, outcome.price)
        suffix = outcome.notified ? ', notif terkirim' : ''
        puts "##{outcome.product_id} #{Format.truncate(outcome.name,
                                                       40)}: #{Format.price(outcome.price)} (#{change}#{suffix})"
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
    end
  end
end
