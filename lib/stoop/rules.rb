# frozen_string_literal: true

module Stoop
  # Decides whether a product should trigger a notification.
  #
  # A product notifies when any of these hold:
  #   1. its price is at or below the target price, or
  #   2. its price dropped at least drop_percent percent below the previous
  #      recorded price, or
  #   3. it is back in stock after being out of stock.
  #
  # Cooldown and deduplication are NOT applied here; they are the
  # notifier's and tracker's job (see Cooldown). This class only answers:
  # "given new data and the previous data point, should we notify, and why?"
  class Rules
    Decision = Struct.new(:notify, :reasons) do
      def initialize(notify:, reasons: [])
        super(notify, reasons)
      end

      def reason_text
        reasons.join('; ')
      end
    end

    DEFAULT_DROP_PERCENT = 10.0

    def initialize(target_price: nil, drop_percent: nil)
      @target_price = target_price
      @drop_percent = drop_percent
    end

    # previous_price may be nil (first check of a product).
    def evaluate(price:, previous_price:, in_stock:, was_in_stock:)
      reasons = []

      reasons << "harga menyentuh target Rp #{format_price(@target_price)}" if @target_price && price <= @target_price

      drop = percent_drop(previous_price, price)
      threshold = @drop_percent || DEFAULT_DROP_PERCENT
      reasons << format('harga turun %.1f%% dari pengecekan sebelumnya', drop) if drop && drop >= threshold

      reasons << 'produk kembali tersedia' if was_in_stock == false && in_stock == true

      Decision.new(notify: !reasons.empty?, reasons: reasons)
    end

    private

    def percent_drop(previous_price, price)
      return nil if previous_price.nil? || previous_price.zero?

      ((previous_price - price).to_f / previous_price) * 100
    end

    def format_price(value)
      value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
    end
  end
end
