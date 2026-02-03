# Basil Arcana Telegram Bot

Minimal Telegram bot built with Node.js + TypeScript and grammY. It draws cards from a static deck registry, calls the Basil’s Arcana API, and sends readings to users with card images hosted in GitHub.

## Features
- Language selection: EN / RU / KZ (kk)
- 1-card and 3-card spreads
- Card images served from GitHub raw URLs by default (with optional local asset fallback)
- Uses Railway secrets for tokens and API keys

## Environment variables (Railway)
Set these in Railway **Secrets**:
- `TELEGRAM_BOT_TOKEN` (required)
- `API_BASE_URL` (default: `https://api.basilarcana.com`)
- `ARCANA_API_KEY` (required)
- `DEFAULT_LOCALE` (`en`, `ru`, or `kk`)
- `FLUTTER_ASSETS_ROOT` (required on Railway, e.g. `/app/basil_arcana/app_flutter/assets`)
- `ASSETS_BASE_PATH` (optional override for local assets path)

> Never commit real secrets. Keep `.env` files out of the repo.

## Local development
From this `bot/` folder:

```bash
npm install
npm run dev
```

You can provide env vars via your shell:

```bash
export TELEGRAM_BOT_TOKEN=...
export ARCANA_API_KEY=...
export API_BASE_URL=https://api.basilarcana.com
export DEFAULT_LOCALE=en
export FLUTTER_ASSETS_ROOT=/absolute/path/to/app_flutter/assets
npm run dev
```

## Railway deployment
- Set the above secrets in Railway.
- Build command: `cd bot && npm ci && npm run build`
- Start command: `cd bot && npm run start`
- Ensure `FLUTTER_ASSETS_ROOT` points to the Flutter assets directory in the container.

## Assets
The bot resolves exact filenames from the local Flutter assets directory and
converts WEBP → PNG before sending to Telegram for reliability.
