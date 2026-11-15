# frozen_string_literal: true

require 'faraday'
require 'json'
require_relative 'base'
require_relative '../version'

module Stoop
  module Notifiers
    # Sends messages through the Telegram Bot API (sendMessage).
    # Uses faraday directly instead of a bot framework to keep the
    # dependency surface small. The token comes from the
    # TELEGRAM_BOT_TOKEN environment variable and is never logged:
    # error messages only contain the HTTP status and Telegram's own
    # description, which does not include the token.
    class Telegram < Base
      API_BASE = 'https://api.telegram.org'

      def initialize(bot_token: nil, chat_id: nil, faraday: nil)
        super()
        @bot_token = bot_token || ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
        @chat_id = chat_id || ENV.fetch('TELEGRAM_CHAT_ID', nil)
        raise NotifierError, 'TELEGRAM_BOT_TOKEN is not set' if @bot_token.to_s.empty?
        raise NotifierError, 'TELEGRAM_CHAT_ID is not set' if @chat_id.to_s.empty?

        @faraday = faraday || build_connection
      end

      def deliver(message)
        response = @faraday.post("/bot#{@bot_token}/sendMessage") do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = { chat_id: @chat_id, text: message, disable_notification: false }.to_json
        end

        parsed = parse_json(response.body)
        return true if response.status == 200 && parsed['ok'] == true

        description = parsed['description'] || 'unknown error'
        raise NotifierError, "Telegram API error (HTTP #{response.status}): #{description}"
      rescue Faraday::Error, JSON::ParserError => e
        raise NotifierError, "Telegram request failed: #{e.class}"
      end

      private

      def build_connection
        Faraday.new(url: API_BASE) do |f|
          f.options.open_timeout = 5
          f.options.timeout = 10
        end
      end

      def parse_json(body)
        JSON.parse(body.to_s)
      end
    end
  end
end
