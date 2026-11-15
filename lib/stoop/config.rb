# frozen_string_literal: true

require 'yaml'
require 'erb'

module Stoop
  # Configuration: tunables from config.yml (optional), secrets from ENV.
  #
  # Lookup order:
  #   1. STOOP_CONFIG environment variable (path to a yml file)
  #   2. ./config.yml
  #   3. ~/.stoop/config.yml
  #   4. built-in defaults
  #
  # Secrets (TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID) come from ENV only, never
  # from config.yml. If a .env file exists next to the working directory it
  # is loaded into ENV (simple KEY=VALUE, comments and blank lines allowed).
  class Config
    DEFAULTS = {
      'check_interval_minutes' => 60,
      'cooldown_hours' => 12,
      'stale_after_failures' => 3,
      'notify_on_restock' => true,
      'default_drop_percent' => 10,
      'database' => nil,
      'user_agent' => nil
    }.freeze

    attr_reader :values

    def self.load(path: nil, env: ENV)
      new.load(path: path, env: env)
    end

    def initialize
      @values = DEFAULTS.dup
    end

    def load(path: nil, env: ENV)
      load_dotenv(env)

      file = path || env['STOOP_CONFIG'] || detect_config_file
      raw = file && File.exist?(file) ? YAML.safe_load_file(file, aliases: false) : {}
      raise ArgumentError, "config file #{file} must contain a YAML mapping" unless raw.nil? || raw.is_a?(Hash)

      @values = DEFAULTS.merge((raw || {}).transform_keys(&:to_s))
      self
    rescue Psych::Exception => e
      raise ArgumentError, "config file #{file} is invalid: #{e.message}"
    end

    def [](key)
      @values[key.to_s]
    end

    def telegram_bot_token(env: ENV)
      env['TELEGRAM_BOT_TOKEN']
    end

    def telegram_chat_id(env: ENV)
      env['TELEGRAM_CHAT_ID']
    end

    def telegram_configured?(env: ENV)
      !telegram_bot_token(env: env).to_s.empty? && !telegram_chat_id(env: env).to_s.empty?
    end

    def database_path(env: ENV)
      env['STOOP_DB'] || self['database'] || File.join(Dir.home, '.stoop', 'stoop.db')
    end

    def check_interval_minutes
      Integer(self['check_interval_minutes'])
    end

    def cooldown_hours
      Float(self['cooldown_hours'])
    end

    def stale_after_failures
      Integer(self['stale_after_failures'])
    end

    def notify_on_restock?
      self['notify_on_restock'] ? true : false
    end

    private

    def detect_config_file
      [File.expand_path('config.yml'), File.join(Dir.home, '.stoop', 'config.yml')].find { |f| File.exist?(f) }
    end

    # Minimal .env loader: KEY=VALUE lines, # comments, optional surrounding
    # quotes. Does not override variables already set in the environment.
    def load_dotenv(env)
      path = File.expand_path('.env')
      return unless File.exist?(path)

      File.readlines(path, chomp: true).each do |raw|
        line = raw.strip
        next if line.empty? || line.start_with?('#')

        key, value = line.split('=', 2)
        next if key.nil? || value.nil?

        key = key.strip
        value = value.strip.gsub(/\A(['"])(.*)\1\z/, '\2')
        next if key.empty? || env.key?(key)

        env[key] = value
      end
    rescue Errno::EACCES, Errno::EISDIR
      nil
    end
  end
end
