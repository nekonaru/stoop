# Changelog

All notable changes to this project are documented here.

## v0.1.0

First release. Stoop is a command line price watcher: it tracks product prices from watched URLs, stores history in a local SQLite database, and sends a Telegram message when a price reaches your target.

## New features

- **Watchlist commands.** `add`, `list`, `remove`, `check`, `history`, `export` and `run` manage products and their prices from the terminal.
- **Price extraction.** JSON-LD (`schema.org/Product`) is the primary source, with meta tags and a per-product CSS selector as fallbacks.
- **Indonesian price parser.** Parses `Rp1.250.000`, `Rp 1.250.000,00`, `IDR 1.250.000` and similar formats into integer rupiah.
- **SQLite storage.** Products and price points live locally at `~/.stoop/stoop.db` (override with `STOOP_DB`).
- **Telegram notifications.** Plain-text messages in Bahasa Indonesia with the product name, current price, previous price, target and URL.
- **Notification rules.** Notify on target reached, a configured percentage drop, or the product coming back in stock.
- **No spam.** A 12 hour cooldown per product and deduplication of identical prices; restock events notify even for the same price.
- **Stale detection.** After three consecutive failures the product is marked stale and you get one alert; it recovers on the next success.
- **Watch loop.** `stoop run` checks prices on a schedule (minimum 30 minutes) with retry and backoff for transient HTTP failures.
- **Etiquette.** robots.txt is honored (a path that cannot be verified is never fetched), requests are rate limited per host, the User-Agent is honest, and there is no anti-bot bypass.
- **Adapter system.** Site-specific adapters can be written in about 30 lines; a working example ships in `lib/stoop/adapters/example_shop.rb`.

## Improvements

- **Formatted output.** Tables, rupiah formatting, percent change and sanitized display of untrusted page-derived names.
- **Security hardening.** Secrets come from ENV only, error messages never include the Telegram token, responses are capped at 10 MB, YAML aliases are disabled, and CSV exports neutralize formula injection.
- **CI and quality gates.** RuboCop, RSpec on Ubuntu/Windows/macOS with Ruby 3.2 to 3.4, a coverage gate for the parser and rules, a secret scan on every push, and SHA-pinned GitHub Actions with locked, checksum-verified gems.
- **Bilingual documentation.** README in English and Bahasa Indonesia, plus a public security policy.
