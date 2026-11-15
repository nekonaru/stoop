# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoop::RateLimiter do
  subject(:limiter) { described_class.new(min_interval: 5.0, clock: clock, sleeper: sleeper) }

  let(:sleeper) { ->(seconds) { slept << seconds } }
  let(:slept) { [] }
  let(:clock) { -> { @now } }

  before { @now = 1000.0 }

  def advance(seconds)
    @now += seconds
  end

  it 'does not sleep before the first request' do
    limiter.wait_for('example.com')
    expect(slept).to be_empty
  end

  it 'sleeps the remaining time when called twice within the interval' do
    limiter.wait_for('example.com')
    advance(2)
    limiter.wait_for('example.com')
    expect(slept).to eq([3.0])
  end

  it 'does not sleep after the interval elapses' do
    limiter.wait_for('example.com')
    advance(6)
    limiter.wait_for('example.com')
    expect(slept).to be_empty
  end

  it 'tracks hosts independently' do
    limiter.wait_for('a.com')
    advance(1)
    limiter.wait_for('b.com')
    expect(slept).to be_empty
  end
end
