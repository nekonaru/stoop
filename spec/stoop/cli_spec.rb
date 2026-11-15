# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Stoop::CLI do
  it 'prints the version' do
    expect { described_class.start(['version']) }.to output(/#{Stoop::VERSION}/).to_stdout
  end

  it 'exits with success on --help' do
    expect { described_class.start(['--help']) }.to output(/Commands|version/).to_stdout
  end
end
