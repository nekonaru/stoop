# frozen_string_literal: true

require_relative 'adapters'
require_relative 'rules'
require_relative 'db'
require_relative 'config'
require_relative 'notifiers/telegram'

module Stoop
  # Orchestrates one check cycle: fetch the current price, record it,
  # decide whether to notify, send the notification, and persist the
  # outcome. Knows about cooldown and deduplication (FR-8).
  class Tracker
    CheckOutcome = Struct.new(:product_id, :name, :price, :previous_price,
                              :notified, :decision, :error, keyword_init: true)

    def initialize(db:, config: Config.load, notifier: :auto, adapter_factory: nil)
      @db = db
      @config = config
      @adapter_factory = adapter_factory || ->(url) { Adapters.for_url(url) }
      @notifier = build_notifier(notifier)
    end

    def check_all(id: nil)
      products = if id
                   [@db.find_product(Integer(id))].compact
                 else
                   @db.list_products
                 end

      products.map { |product| check_product(product) }
    end

    def check_product(product)
      previous = @db.latest_price_point(product['id'])
      was_price = previous && previous['price']
      was_in_stock = previous ? previous['in_stock'] == 1 : nil

      result = fetch(product)
      record_success(product, result)
      decision = decide(product, result, was_price, was_in_stock)
      notified = deliver_if_wanted?(product, result, decision)

      CheckOutcome.new(product_id: product['id'], name: product['name'],
                       price: result.price, previous_price: was_price,
                       notified: notified, decision: decision)
    rescue StandardError => e
      @db.record_failure(product['id'])
      handle_stale(product)
      CheckOutcome.new(product_id: product['id'], name: product['name'], error: e.message)
    end

    private

    def build_notifier(notifier)
      return nil if notifier.nil?
      return notifier unless notifier == :auto

      return nil unless @config.telegram_configured?

      Notifiers::Telegram.new
    rescue Notifiers::NotifierError
      nil
    end

    def fetch(product)
      adapter = @adapter_factory.call(product['url'])
      adapter.fetch(product['url'], selector: product['selector'])
    end

    def record_success(product, result)
      @db.record_price_point(product_id: product['id'], price: result.price,
                             currency: result.currency, in_stock: result.in_stock)
      @db.reset_failures(product['id'])
    end

    def decide(product, result, was_price, was_in_stock)
      Rules.new(target_price: product['target_price'],
                drop_percent: product['drop_percent'] || @config['default_drop_percent'])
           .evaluate(price: result.price, previous_price: was_price,
                     in_stock: result.in_stock, was_in_stock: was_in_stock)
    end

    def deliver_if_wanted?(product, result, decision)
      return false unless decision.notify
      return false if @notifier.nil?
      return false unless cooldown_elapsed?(product)
      return false if duplicate_price?(product, result.price, decision)

      @notifier.deliver(notification_message(product, result, decision))
      @db.record_notification(product['id'], price: result.price)
      true
    end

    def cooldown_elapsed?(product)
      last = product['last_notified_at']
      return true if last.nil? || last.to_s.empty?

      (Time.now.utc - Time.parse(last)) >= @config.cooldown_hours * 3600
    rescue ArgumentError
      true
    end

    # Never notify twice for the exact same price, unless the reason is a
    # restock (which is rare and meaningful) and restock alerts are enabled.
    def duplicate_price?(product, price, decision)
      restock = decision.reason_text.include?('kembali')
      return false if restock && @config.notify_on_restock?

      !product['last_notified_price'].nil? && product['last_notified_price'] == price
    end

    def handle_stale(product)
      failures = @db.find_product(product['id'])['consecutive_failures']
      return if failures < @config.stale_after_failures
      return if @db.stale_notified?(product['id'])

      @db.mark_stale(product['id'], notified_at: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'))
      notify_stale(product, failures)
    end

    def notify_stale(product, failures)
      return if @notifier.nil?

      @notifier.deliver("Stoop: #{product['name']} gagal dipantau #{failures}x berturut-turut. " \
                        "Cek URL dan adapter, lalu jalankan stoop check #{product['id']}.\n#{product['url']}")
    rescue Notifiers::NotifierError
      nil
    end

    def notification_message(product, result, decision)
      previous = @db.previous_price_point(product['id'])
      lines = ["Stoop: #{product['name']}"]
      lines << "Sekarang: Rp #{format_price(result.price)}"
      lines << "Sebelumnya: Rp #{format_price(previous['price'])}" if previous
      lines << "Target: Rp #{format_price(product['target_price'])}" if product['target_price']
      lines << decision.reason_text
      lines << product['url']
      lines.join("\n")
    end

    def format_price(value)
      value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1.').reverse
    end
  end
end
