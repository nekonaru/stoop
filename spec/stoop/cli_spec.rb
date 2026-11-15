# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'stoop/cli'

RSpec.describe Stoop::CLI do
  let(:dir) { Dir.mktmpdir }
  let(:db_path) { File.join(dir, 'stoop-test.db') }

  before do
    ENV['STOOP_DB'] = db_path
  end

  after do
    ENV.delete('STOOP_DB')
    ObjectSpace.each_object(Stoop::DB) do |db|
      db.close
    rescue StandardError
      nil
    end
    remove_tree(dir)
  end

  def result(price: 249_000, name: 'Sepatu Test')
    Stoop::Adapters::Result.new(name: name, price: price, currency: 'IDR', in_stock: true)
  end

  def adapter_double
    instance_double(Stoop::Adapters::Generic)
  end

  describe 'version' do
    it 'prints the version' do
      expect { described_class.start(['version']) }.to output(/#{Stoop::VERSION}/).to_stdout
    end
  end

  describe 'add' do
    it 'adds a product, fetching its name' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_return(result)
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      expect { described_class.start(['add', 'https://shop.example.com/1', '--target', '250000']) }
        .to output(/Added product #1: Sepatu Test/).to_stdout
    end

    it 'rejects a duplicate URL' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_return(result)
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      described_class.start(['add', 'https://shop.example.com/1'])
      expect { described_class.start(['add', 'https://shop.example.com/1']) }
        .to raise_error(SystemExit).and output(/already in watchlist/).to_stderr
    end

    it 'rejects a non-http URL' do
      expect { described_class.start(['add', 'ftp://shop.example.com/1']) }
        .to raise_error(SystemExit).and output(/http or https/).to_stderr
    end
  end

  describe 'check' do
    it 'fetches the price and stores a price point' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_return(result(price: 249_000))
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      described_class.start(['add', 'https://shop.example.com/1', '--name', 'Sepatu Test'])
      expect { described_class.start(['check']) }
        .to output(/#1 Sepatu Test: Rp 249\.000/).to_stdout.and raise_error(SystemExit)
    end

    it 'reports failures without crashing and exits 1' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_raise(Stoop::Adapters::ParseError, 'no price found')
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      described_class.start(['add', 'https://shop.example.com/1', '--name', 'Sepatu Test'])
      expect { described_class.start(['check']) }
        .to raise_error(SystemExit).and output(/gagal: no price found/).to_stderr
    end
  end

  describe 'list' do
    it 'shows an empty watchlist message' do
      expect { described_class.start(['list']) }.to raise_error(SystemExit)
    end
  end

  describe 'remove' do
    it 'removes the product' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_return(result)
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      described_class.start(['add', 'https://shop.example.com/1', '--name', 'Sepatu Test'])
      expect { described_class.start(%w[remove 1]) }.to output(/Removed product #1/).to_stdout
    end

    it 'fails for an unknown ID' do
      expect { described_class.start(%w[remove 99]) }.to raise_error(SystemExit)
    end
  end

  describe 'export' do
    it 'exports price history as CSV to stdout' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_return(result(price: 249_000))
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      described_class.start(['add', 'https://shop.example.com/1', '--name', 'Sepatu Test'])
      expect { described_class.start(['check']) }.to raise_error(SystemExit)
      expect { described_class.start(['export']) }
        .to output(/product_id,name,url,checked_at,price,currency,in_stock/).to_stdout
    end

    it 'writes CSV to a file' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_return(result(price: 249_000))
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      described_class.start(['add', 'https://shop.example.com/1', '--name', 'Sepatu Test'])
      expect { described_class.start(['check']) }.to raise_error(SystemExit)

      output_path = File.join(dir, 'export.csv')
      expect { described_class.start(['export', '--output', output_path]) }
        .to output(/Exported 1 rows/).to_stdout
      content = File.read(output_path)
      expect(content).to include('Sepatu Test').and include('249000')
    end
  end

  describe 'run' do
    it 'runs a single check cycle with --once' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_return(result(price: 249_000))
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      described_class.start(['add', 'https://shop.example.com/1', '--name', 'Sepatu Test'])
      expect { described_class.start(['run', '--once']) }
        .to output(/cycle complete: 1 products/).to_stdout
    end
  end

  describe 'history' do
    it 'shows stored price points' do
      adapter = adapter_double
      allow(adapter).to receive(:fetch).and_return(result(price: 249_000))
      allow(Stoop::Adapters).to receive(:for_url).and_return(adapter)

      described_class.start(['add', 'https://shop.example.com/1', '--name', 'Sepatu Test'])
      expect { described_class.start(['check']) }.to raise_error(SystemExit)
      expect { described_class.start(%w[history 1]) }.to output(/249\.000/).to_stdout
    end
  end
end
