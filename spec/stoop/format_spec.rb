# frozen_string_literal: true

require 'spec_helper'
require 'stoop/format'

RSpec.describe Stoop::Format do
  describe '.csv_cell' do
    it 'quotes cells with commas' do
      expect(described_class.csv_cell('a,b')).to eq('"a,b"')
    end

    it 'doubles quotes inside cells' do
      expect(described_class.csv_cell('say "hi"')).to eq('"say ""hi"""')
    end

    it 'neutralizes formula injection with a leading quote' do
      expect(described_class.csv_cell('=1+1')).to eq("'=1+1")
      expect(described_class.csv_cell('+SUM(A1)')).to eq("'+SUM(A1)")
      expect(described_class.csv_cell('-10')).to eq("'-10")
      expect(described_class.csv_cell('@cmd')).to eq("'@cmd")
    end

    it 'strips terminal control characters' do
      expect(described_class.csv_cell("a\x1b[2Jb")).to eq('a[2Jb')
    end

    it 'leaves plain values untouched' do
      expect(described_class.csv_cell('Sepatu Lari')).to eq('Sepatu Lari')
      expect(described_class.csv_cell(249_000)).to eq('249000')
    end
  end

  describe '.plain' do
    it 'removes control and format characters' do
      expect(described_class.plain("a\u0007b\u200Bc")).to eq('abc')
    end
  end

  describe '.truncate' do
    it 'strips control characters before truncating' do
      expect(described_class.truncate("a\u001b[2Jxyz", 10)).to eq('a[2Jxyz')
    end
  end
end
