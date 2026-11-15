# Design decisions

## 2026-11-15: Project kind and packaging

- Stoop is a general-kind project: a command line tool and daemon, distributed through the repository (no registry publishing in v0.1.0).
- Ruby 3.2+, gem set fixed by the PRD: nokogiri, faraday, sqlite3, thor, rufus-scheduler, rspec, webmock, rubocop.
- Telegram notifications are delivered with plain HTTP (faraday), no bot framework, to keep the dependency surface small.
- Secrets only from environment variables (`TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`). Nothing secret is logged or committed; `.env` is gitignored and `.env.example` documents the variables.

## 2026-11-15: Release pipeline

- Branch, PR, CI (rubocop, rspec, coverage gate for price parser and rules, secret scan), squash merge, then a signed tag `vX.Y.Z` once CI is green on `main`.
- Release notes are bilingual (English first, Bahasa Indonesia second) following the release template, with `CHANGELOG.md` and `CHANGELOG.id.md` kept in sync.
- License is MIT.

## 2026-11-15: Brand assets

- The mark is a descending staircase with a red dot (price drop), drawn from the provided artwork.
- `assets/stoop-mark.svg` and `assets/stoop-mark-dark.svg` are vector masters built from measured geometry; `assets/stoop-mark.png` and `assets/stoop-mark-dark.png` are renders used in the README header and assets.
- The full lockups (`assets/stoop-logo-light.png`, `assets/stoop-logo-dark.png`) are cropped from the provided image and keep the original composition.
