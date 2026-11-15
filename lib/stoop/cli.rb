# frozen_string_literal: true

require 'thor'
require_relative 'version'

module Stoop
  # Command line interface for Stoop.
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'version', 'Print the Stoop version'
    def version
      puts "Stoop #{VERSION}"
    end

    map %w[-v --version] => :version
  end
end
