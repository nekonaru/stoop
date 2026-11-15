# frozen_string_literal: true

require 'spec_helper'
require 'stoop/rules'

RSpec.describe Stoop::Rules do
  subject(:rules) { described_class.new(target_price: target, drop_percent: drop_percent) }

  let(:target) { 250_000 }
  let(:drop_percent) { 10 }

  def evaluate(price:, previous_price: nil, in_stock: true, was_in_stock: true)
    rules.evaluate(price: price, previous_price: previous_price, in_stock: in_stock, was_in_stock: was_in_stock)
  end

  it 'notifies when the price reaches the target' do
    decision = evaluate(price: 249_000)
    expect(decision.notify).to be(true)
    expect(decision.reason_text).to include('target')
  end

  it 'notifies when the price is exactly the target' do
    expect(evaluate(price: 250_000).notify).to be(true)
  end

  it 'notifies when the price drops more than the threshold' do
    decision = evaluate(price: 400_000, previous_price: 500_000)
    expect(decision.notify).to be(true)
    expect(decision.reason_text).to include('turun')
  end

  it 'does not notify when the drop is below the threshold' do
    expect(evaluate(price: 475_000, previous_price: 500_000).notify).to be(false)
  end

  it 'does not notify on the first check' do
    expect(evaluate(price: 100_000).notify).to be(true) # reaches the 250k target
    expect(evaluate(price: 400_000).notify).to be(false)
  end

  it 'notifies when the product is back in stock' do
    decision = evaluate(price: 400_000, was_in_stock: false, in_stock: true)
    expect(decision.notify).to be(true)
    expect(decision.reason_text).to include('kembali')
  end

  it 'reports multiple reasons at once' do
    decision = evaluate(price: 249_000, previous_price: 500_000, was_in_stock: false, in_stock: true)
    expect(decision.reasons.size).to be >= 2
  end

  it 'does not notify when the price rises' do
    expect(evaluate(price: 300_000, previous_price: 250_000).notify).to be(false)
  end

  it 'uses the default drop percent when none is configured' do
    default_rules = described_class.new(target_price: nil, drop_percent: nil)
    decision = default_rules.evaluate(price: 400_000, previous_price: 500_000,
                                      in_stock: true, was_in_stock: true)
    expect(decision.notify).to be(true)
  end

  it 'treats a zero previous price safely' do
    expect { evaluate(price: 100_000, previous_price: 0) }.not_to raise_error
  end
end
