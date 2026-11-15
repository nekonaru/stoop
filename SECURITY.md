# Security Policy

## Reporting a vulnerability

Stoop is an open-source command line tool. If you find a security vulnerability, report it privately. Do not open a public issue.

- Preferred: use GitHub's private vulnerability reporting (Report a vulnerability button on the Security tab of this repository).
- Alternative: email the maintainer at nicolasdwidharma@gmail.com.

Include what you can: the affected version or commit, steps to reproduce, and what you observed. Expect an acknowledgement within a few days.

## Scope

- The Stoop CLI and its Telegram notification path.
- Credential handling (ENV only), the release pipeline, and the bundled gems in `Gemfile.lock`.

Out of scope: vulnerabilities in merchant websites Stoop reads from, and vulnerabilities in the Telegram Bot API itself. Report those to the respective sites and to Telegram.

## What Stoop does to stay safe

- Secrets come from environment variables only and are never logged. Telegram API errors surface the HTTP status and Telegram's description, never the token.
- All outbound requests use an honest User-Agent, timeouts, per-host rate limiting, and a 10 second read timeout. Bodies over 10 MB are refused.
- robots.txt is honored: disallowed URLs are never fetched.
- SQL uses parameterized queries. No shell is ever invoked. No eval, no YAML aliases (plain YAML only).
- Responses are not redirected implicitly.
- CI enforces RuboCop, the RSpec suite, a minimum coverage gate and a secret scan before any merge.
- Dependencies are locked in `Gemfile.lock` and updated via Dependabot.

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |

## Ethics

Stoop does not bypass anti-bot protection, logins or CAPTCHAs, and it honors robots.txt. If a site does not allow automated access, Stoop says so and does not fetch it.
