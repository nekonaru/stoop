# frozen_string_literal: true

require_relative 'stoop/version'
require_relative 'stoop/price_parser'
require_relative 'stoop/rate_limiter'
require_relative 'stoop/http_client'
require_relative 'stoop/robots'
require_relative 'stoop/adapters'
require_relative 'stoop/config'
require_relative 'stoop/db'
require_relative 'stoop/cli'

# Stoop is a command line tool that watches product prices from a list of
# URLs and sends a Telegram notification when a price reaches its target.
module Stoop
end
