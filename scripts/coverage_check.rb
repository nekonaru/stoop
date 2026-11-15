#!/usr/bin/env ruby
# frozen_string_literal: true

# Runs the test suite with coverage, then fails if any target file falls
# below the required line coverage. Uses only the Ruby standard library.

require 'coverage'

ROOT = File.expand_path('..', __dir__)
$LOAD_PATH.unshift File.join(ROOT, 'lib')

TARGETS = %w[price_parser rules].map { |name| File.join(ROOT, 'lib', 'stoop', "#{name}.rb") }
MIN_COVERAGE = 80.0

Coverage.start(lines: true)

require 'rspec/core'
status = RSpec::Core::Runner.run(['spec'])
result = Coverage.result

targets = TARGETS.select { |target| File.exist?(target) }
if targets.empty?
  puts 'coverage: no target files present, skipping gate'
  exit(status.zero? ? 0 : 1)
end

ok = true
targets.each do |target|
  entry = result.find { |file, _| File.expand_path(file) == target }
  if entry.nil?
    puts "coverage: #{target} was not loaded"
    ok = false
    next
  end
  covered = entry[1][:lines].count { |line| !line.nil? && line.positive? }
  total = entry[1][:lines].count { |line| !line.nil? }
  next if total.zero?

  percent = 100.0 * covered / total
  puts format('coverage: %<file>s %<percent>.1f%% (%<covered>d/%<total>d)',
              file: File.basename(target), percent: percent, covered: covered, total: total)
  ok = false if percent < MIN_COVERAGE
end

exit(ok && status.zero? ? 0 : 1)
