# frozen_string_literal: true

module Stoop
  # Parses Indonesian rupiah price strings into integer rupiah.
  #
  # Handles the formats shops actually use: "Rp1.250.000", "Rp 1.250.000,00",
  # "IDR 1.250.000", thousand separators written as dots or commas, a trailing
  # ",-", and either nbsp or plain spaces. Decimals are truncated to whole
  # rupiah, which matches how marketplace prices are displayed.
  #
  # Returns nil when the input cannot be parsed as a price.
  class PriceParser
    CURRENCY_PREFIX = /\A(?:rp\.?|idr|rupiah)?/i
    NUMBER_PATTERN = /\A\d{1,3}([.,]\d{3})*([.,]\d{1,2})?\z|\A\d+\z/

    def self.parse(text)
      new.parse(text)
    end

    def parse(text)
      return nil if text.nil?

      cleaned = normalize(text)
      return nil if cleaned.nil?

      parse_number(cleaned)
    end

    private

    def normalize(text)
      str = text.to_s.strip
      str = str.gsub("\u00A0", ' ')          # nbsp to space
      str = str.gsub(/\s+/, ' ')             # collapse spaces
      str = str.gsub(/(,|\.)-\z/, '')        # trailing ",-" style
      str = str.sub(CURRENCY_PREFIX, '').strip
      return nil if str.empty?
      return nil if str.match?(/-/)          # negative amounts are not prices

      str = str.gsub(' ', '')
      return nil unless NUMBER_PATTERN.match?(str)

      str
    end

    def parse_number(str)
      last_dot = str.rindex('.')
      last_comma = str.rindex(',')

      if last_dot && last_comma
        decimal_at = [last_dot, last_comma].max
        parse_with_decimal(str, decimal_at)
      elsif last_dot
        parse_single_separator(str, '.')
      elsif last_comma
        parse_single_separator(str, ',')
      else
        Integer(str, 10)
      end
    end

    # Both separators present: the rightmost one is the decimal separator.
    def parse_with_decimal(str, decimal_at)
      integer_part = str[0...decimal_at].gsub(/[.,]/, '')
      decimal_part = str[(decimal_at + 1)..]
      Float("#{integer_part}.#{decimal_part}").floor
    rescue ArgumentError, TypeError
      nil
    end

    # One separator type present. Multiple occurrences are thousand
    # separators. A single occurrence with three digits after it is a
    # thousand separator (Indonesian style); one or two digits after it is a
    # decimal separator.
    def parse_single_separator(str, sep)
      occurrences = str.count(sep)
      return Integer(str.gsub(sep, ''), 10) if occurrences > 1

      before, after = str.split(sep, 2)
      if after.length == 3
        Integer("#{before}#{after}", 10)
      else
        Float("#{before}.#{after}").floor
      end
    rescue ArgumentError, TypeError
      nil
    end
  end
end
