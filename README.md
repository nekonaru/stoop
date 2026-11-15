<div align="center">
  <img src="assets/stoop-mark.png" alt="Stoop logo" width="120" />
  <h1>Stoop: Product Price Watcher with Telegram Alerts</h1>
  <p><b>Track product prices from watched URLs and get a Telegram message<br/>
  when a price hits your target. Local-first, no account needed.</b></p>

  <a href="https://github.com/nekonaru/stoop/releases"><img src="https://img.shields.io/github/v/release/nekonaru/stoop?style=flat-square&color=blue" alt="Release" /></a>
  <a href="https://github.com/nekonaru/stoop/actions/workflows/ci.yml"><img src="https://github.com/nekonaru/stoop/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <img src="https://img.shields.io/badge/Ruby-3.2%2B-CC342D?style=flat-square&logo=ruby&logoColor=white" alt="Ruby" />
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-555?style=flat-square" alt="Platform" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen?style=flat-square" alt="Status" />
</div>

<br />

**English** | [Bahasa Indonesia](README.id.md)

> [!NOTE]
> Stoop is a personal automation tool, not a scraping service. It honors robots.txt, applies rate limits, and refuses to fetch what a site does not allow.

---

## Table of Contents

- [About](#about)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Writing an Adapter](#writing-an-adapter)
- [Project Structure](#project-structure)
- [Development](#development)
- [Testing](#testing)
- [Security](#security)
- [Continuous Integration](#continuous-integration)
- [FAQ](#faq)
- [Author](#author)
- [Disclaimer](#disclaimer)
- [License](#license)

---

## About

**Stoop** is a command line tool that watches product prices for you. Add product URLs to a local watchlist, and Stoop fetches the current price on demand or on a schedule, stores the history in a local SQLite database, and sends a Telegram notification when a price hits your target, drops by a percentage you choose, or comes back in stock. It is for people who want to catch price drops without an app, an account or a subscription.

> _"Stoop watches the price. You get the deal."_

---

## Features

### Watchlist

| Feature | Description |
|---------|-------------|
| **Add products** | `stoop add <url> --target 250000` adds a product to the watchlist |
| **List products** | `stoop list` prints a table with the latest price, target, drop and status |
| **Remove products** | `stoop remove <id>` deletes a product and its price history |
| **Per-product targets** | Set a target price, a drop percentage, or both, per product |
| **Price history** | `stoop history <id>` shows the price history as a table with change per check |
| **CSV export** | `stoop export [id]` exports price history as CSV to stdout or a file |

### Price Checking

| Feature | Description |
|---------|-------------|
| **On-demand checks** | `stoop check [id]` fetches the current price for all active products or one |
| **Watch loop** | `stoop run` checks prices on a configurable interval (minimum 30 minutes) |
| **JSON-LD first** | Structured data (`schema.org/Product`) is the primary source, meta tags and a CSS selector are fallbacks |
| **Indonesian prices** | Parses `Rp1.250.000`, `Rp 1.250.000,00`, `IDR 1.250.000` and similar formats |
| **Retry with backoff** | 5xx and network errors retry up to 3 times, 4xx does not retry |
| **Stale detection** | After consecutive failures (default 3) the product is marked stale and you get one alert |

### Notifications

| Feature | Description |
|---------|-------------|
| **Telegram alerts** | Sends a message through the Telegram Bot API (token from ENV only) |
| **Trigger rules** | Notifies when price hits the target, drops by X percent, or is back in stock |
| **No spam** | 12 hour cooldown per product and deduplication of identical prices |
| **Honest messages** | Plain text in Bahasa Indonesia: name, price, previous price, target, URL |

### Etiquette

| Feature | Description |
|---------|-------------|
| **robots.txt honored** | Disallowed URLs are never fetched |
| **Rate limited** | At most one request per host per 5 seconds |
| **Honest User-Agent** | Identifies as `Stoop/<version> (+https://github.com/nekonaru/stoop)` |
| **No bypassing** | No anti-bot evasion, no login, no CAPTCHA bypass, no robots.txt violation |

---

## Requirements

| Dependency | Minimum Version | Notes |
|------------|-----------------|-------|
| **Ruby** | 3.2 | Ships with bundled gems; `gem --version` should work |
| **SQLite** | 3.x | Embedded, no server needed |
| **Git** | any | For installing from source |
| **Telegram bot** | - | Only needed for notifications; create one with @BotFather |

> [!TIP]
> You do not need to build anything. Installing from source is a few commands (see below).

### Never used a terminal? Start here

<details>
<summary><b>Opening a terminal on your system</b></summary>

1. **Linux:** press `Ctrl+Alt+T` and type your commands there.
2. **macOS:** press `Cmd+Space`, type `Terminal`, press Enter.
3. **Windows:** press `Win+X`, choose `Terminal` or `PowerShell`.

</details>

---

## Installation

### Option A: Install from source

<details>
<summary><b>I have Git installed</b></summary>

```bash
git clone https://github.com/nekonaru/stoop.git
cd stoop
bundle install
bundle exec bin/stoop version
```

</details>

<details>
<summary><b>I don't have Git</b></summary>

1. Download the [latest release](https://github.com/nekonaru/stoop/releases) as a ZIP from GitHub, or use this command to clone with the GitHub CLI.
2. Unzip it and open a terminal in the folder.
3. Run `bundle install` and `bundle exec bin/stoop version`.

</details>

> [!IMPORTANT]
> `bundle exec bin/stoop` is the smoke test. If it prints `Stoop 0.1.0`, the install works.

For convenience, add Stoop to your PATH so `stoop` works without `bundle exec bin/stoop`:

```bash
alias stoop='bundle exec ruby /path/to/stoop/bin/stoop'
```

---

## Configuration

### 1. Telegram bot (for notifications)

> [!IMPORTANT]
> Steps 2 to 4 give you two secrets. Never commit them.

1. Open Telegram and message **@BotFather**.
2. Send `/newbot`, follow the prompts, and copy the **bot token** it gives you.
3. Send any message to your new bot (for example `/start`).
4. Open `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates` in a browser and copy the `chat.id` from the JSON response. That is your **chat id**.
5. Export both as environment variables, for example in `~/.bashrc`, `~/.zshrc`, or your CI/cron environment:

```bash
export TELEGRAM_BOT_TOKEN="123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
export TELEGRAM_CHAT_ID="123456789"
```

Alternatively, copy `.env.example` to `~/.stoop/.env` and fill it in. Stoop loads `~/.stoop/.env` from the current user's home directory if it exists. Never commit `.env`.

### 2. Settings (optional)

Copy `config.example.yml` to `~/.stoop/config.yml` and adjust:

```yaml
check_interval_minutes: 60   # daemon interval, minimum 30
cooldown_hours: 12           # notification cooldown per product
stale_after_failures: 3      # consecutive failures before stale
notify_on_restock: true      # notify when a product is back in stock
default_drop_percent: 10     # drop threshold when a product has none
database: ~/.stoop/stoop.db  # path override
```

Stoop reads `STOOP_CONFIG` for a custom config path and `STOOP_DB` for a custom database path.

---

## Usage

### First launch

1. Create a Telegram bot and set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` if you want notifications.
2. Add a product:

```bash
stoop add "https://shop.example.com/product/123" --target 250000
```

3. Check the price once:

```bash
stoop check
```

4. Run it continuously (or set up cron). See below.

### Everyday use

- **See the watchlist**: `stoop list`
- **Check all prices**: `stoop check`
- **Check one product**: `stoop check 3`
- **View history**: `stoop history 3`
- **Export CSV**: `stoop export` or `stoop export 3 --output prices.csv`
- **Run the daemon**: `stoop run` (foreground; stop with Ctrl+C)
- **One check per run**: `stoop run --once` (useful with cron)

### Running with cron

Stoop does not fork or daemonize. For a cron-driven setup:

```cron
*/60 * * * * TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... /path/to/stoop/bin/stoop run --once
```

### How notifications behave

- A notification is sent when **any** of these is true: the price is at or below your target, the price dropped by at least `drop_percent` (or `default_drop_percent`), or the product is back in stock.
- You never get the same price twice, and at most one message per product per 12 hours.
- After 3 consecutive failures a product is marked stale, and you get **one** alert. It resets on the next success.

---

## Writing an Adapter

Most sites work out of the box. Stoop tries, in order:

1. **JSON-LD** (`schema.org/Product` in a `<script type="application/ld+json">`)
2. **Meta tags** (`product:price:amount` / `og:price:amount`)
3. **A CSS selector you pass per product**: `stoop add <url> --selector ".product-price"`

For a site that needs more, write a site adapter in about 30 lines:

```ruby
# lib/stoop/adapters/my_shop.rb
# frozen_string_literal: true

require_relative 'generic'

module Stoop
  module Adapters
    # Adapter for myshop.example.com.
    class MyShop < Generic
      SITE_DOMAINS = %w[myshop.example.com www.myshop.example.com].freeze

      # Override fetch or the extraction helpers from Generic.
      # Return Result.new(name:, price:, currency:, in_stock:).
    end
  end
end
```

Then register it in `lib/stoop/adapters.rb`:

```ruby
SITE_ADAPTERS = [ExampleShop, MyShop].freeze
```

See `lib/stoop/adapters/example_shop.rb` for a working example. Test with HTML fixtures in `spec/fixtures/`, never against the real site.

---

## Project Structure

```
stoop/
├── bin/stoop              # CLI entry point
├── lib/stoop/
│   ├── cli.rb             # command definitions
│   ├── config.rb          # YAML + .env loading
│   ├── db.rb              # SQLite storage
│   ├── tracker.rb         # fetch, record, notify orchestration
│   ├── rules.rb           # when to notify
│   ├── price_parser.rb    # Indonesian price formats
│   ├── http_client.rb     # rate-limited, retrying HTTP
│   ├── robots.rb          # robots.txt gate
│   ├── rate_limiter.rb    # per-host spacing
│   ├── format.rb          # output formatting
│   ├── adapters/          # site adapters
│   │   ├── base.rb
│   │   ├── generic.rb     # JSON-LD / meta / selector
│   │   └── example_shop.rb
│   └── notifiers/
│       ├── base.rb
│       └── telegram.rb
├── spec/
│   ├── stoop/             # unit tests
│   └── fixtures/          # HTML fixtures
├── config.example.yml     # all settings, documented
├── .env.example           # TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
├── docs/decisions.md      # design decision log
├── README.md              # this file
└── README.id.md           # Bahasa Indonesia
```

---

## Development

1. **Install dependencies**: `bundle install`
2. **Run the CLI**: `bundle exec bin/stoop --help`
3. **Add a command**: add a `desc`/`def` pair in `lib/stoop/cli.rb`, add specs in `spec/stoop/cli_spec.rb`.
4. **Add an adapter**: copy `lib/stoop/adapters/example_shop.rb`, register in `lib/stoop/adapters.rb`, add a fixture and a spec.
5. **Style**: `bundle exec rubocop` must report zero offenses.

> [!WARNING]
> Do not commit `.env`, `SECURITY_MAP.md`, `SECURITY_REVIEW.md` or `SECURITY_REPORT.md`. Tests never hit the network; they use WebMock and `spec/fixtures/`.

---

## Testing

```bash
bundle exec rspec                          # 114 examples
bundle exec rubocop                        # 0 offenses
bundle exec ruby scripts/coverage_check.rb # parser and rules above 80%
bundle exec bin/stoop --help               # smoke test
```

| Check | Requirement |
|-------|-------------|
| RSpec | All examples pass |
| RuboCop | 0 offenses |
| Coverage | `price_parser.rb` and `rules.rb` above 80% line coverage |
| Secret scan | Gitleaks runs in CI |

---

## Security

Stoop reads pages on your behalf and stores only what you watch. Verified protections: HTTP requests use an honest User-Agent, TLS verification (faraday defaults), 5 second open and 10 second read timeouts, per-host rate limiting, a 10 MB body cap, and robots.txt is honored. Secrets come from ENV only; error messages never include the Telegram token. Dependencies are locked in `Gemfile.lock` and scanned in CI.

> [!NOTE]
> To report a vulnerability, use GitHub's private vulnerability reporting (see [`SECURITY.md`](SECURITY.md)). Please do not open public issues for security reports.

---

## Continuous Integration

| Workflow | Purpose |
|----------|---------|
| `.github/workflows/ci.yml` | RuboCop, RSpec on Ubuntu/Windows/macOS with Ruby 3.2-3.4, coverage gate, secret scan |
| `.github/dependabot.yml` | Weekly dependency updates for bundler and GitHub Actions |

Every pull request must pass all 10 CI checks plus the secret scan before it can merge. `main` is protected: no force pushes, linear history, admin rules enforced.

---

## FAQ

<details>
<summary><b>Does Stoop bypass anti-bot protection?</b></summary>

No. Stoop never bypasses anti-bot systems, logins or CAPTCHAs. If a site does not allow automated access, Stoop says so and refuses to fetch it.

</details>

<details>
<summary><b>Which sites does it support?</b></summary>

Any site whose product page exposes JSON-LD (`schema.org/Product`) or the usual price meta tags. For anything else you can pass a CSS selector per product, or write a small adapter.

</details>

<details>
<summary><b>Can it watch prices in other currencies?</b></summary>

The parser targets Indonesian rupiah. Other currencies parse as generic numbers but notifications assume rupiah formatting.

</details>

<details>
<summary><b>My Telegram token leaked. What now?</b></summary>

Revoke it immediately with @BotFather (`/revoke`), generate a new one, and update your environment. Never commit tokens; `.env` is gitignored and CI scans for leaks on every push.

</details>

<details>
<summary><b>Where is my data stored?</b></summary>

In a local SQLite file at `~/.stoop/stoop.db` (override with `STOOP_DB`). Nothing is sent anywhere except the pages you watch and, if configured, the Telegram message to your own chat.

</details>

---

## Author

<div align="center">

| [![Nicolas Dwi Dharma](https://github.com/nekonaru.png?size=100)](https://github.com/nekonaru) |
|:---:|
| **Nicolas Dwi Dharma** |
| [@nekonaru](https://github.com/nekonaru) |

</div>

---

## Disclaimer

Stoop is an independent open-source project. It is not affiliated with any marketplace or merchant. Respect each site's terms of service and robots.txt. The authors are not responsible for how the tool is used.

---

## License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.
