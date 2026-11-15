# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoop::PriceParser do
  subject(:parser) { described_class.new }

  describe 'Indonesian rupiah formats' do
    {
      'Rp1.250.000' => 1_250_000,
      'Rp 1.250.000' => 1_250_000,
      'Rp 1.250.000,00' => 1_250_000,
      'Rp1.250.000,00' => 1_250_000,
      'Rp. 1.250.000' => 1_250_000,
      'Rp.1.250.000' => 1_250_000,
      'rp 1.250.000' => 1_250_000,
      'IDR 1.250.000' => 1_250_000,
      'IDR1.250.000' => 1_250_000,
      '1.250.000' => 1_250_000,
      '1250000' => 1_250_000,
      'Rp 249.000' => 249_000,
      'Rp 99.999' => 99_999,
      'Rp 2.499' => 2_499,
      'Rp 1.000.000.000' => 1_000_000_000,
      'Rp 10.000.000' => 10_000_000,
      'Rp 0' => 0,
      "Rp\u00A01.250.000" => 1_250_000, # nbsp
      '  Rp   250.000  ' => 250_000,
      'Rp250.000,-' => 250_000,
      'Rp 1.250.000,50' => 1_250_000 # decimals truncate to whole rupiah
    }.each do |input, expected|
      it "parses #{input.inspect} as #{expected}" do
        expect(parser.parse(input)).to eq(expected)
      end
    end
  end

  describe 'US style input as a fallback' do
    it 'parses thousands commas with a dot decimal' do
      expect(parser.parse('1,250,000.50')).to eq(1_250_000)
    end

    it 'parses thousands commas without a decimal' do
      expect(parser.parse('2,500,000')).to eq(2_500_000)
    end
  end

  describe 'unparseable input' do
    [nil, '', '   ', 'free', 'Rp', 'abc123def', '-Rp 5.000', 'Rp 1,5 jt'].each do |input|
      it "returns nil for #{input.inspect}" do
        expect(parser.parse(input)).to be_nil
      end
    end
  end
end
