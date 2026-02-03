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
- `ASSETS_BASE_URL` (required, e.g. `https://raw.githubusercontent.com/artemovbasil-oss/basil-arcana/main/basil_arcana/app_flutter/assets`)
- `USE_LOCAL_ASSETS` (optional, `true` to send images from local files when assets exist)
- `ASSETS_BASE_PATH` (optional, default: `../app_flutter/assets`)

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
export ASSETS_BASE_URL=https://raw.githubusercontent.com/artemovbasil-oss/basil-arcana/main/basil_arcana/app_flutter/assets
npm run dev
```

## Railway deployment
- Set the above secrets in Railway.
- Ensure `ASSETS_BASE_URL` is set to the GitHub raw assets path.
- Build command: `npm run build`
- Start command: `npm start`
- Ensure the service working directory is `bot/`.

## Assets
The bot sends card images using GitHub raw URLs, built from `ASSETS_BASE_URL`.
If `USE_LOCAL_ASSETS=true` and local assets are available, it sends local files and
falls back to converting WEBP → PNG when needed.
