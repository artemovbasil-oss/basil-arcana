# Basil Arcana Telegram Bot

Minimal Telegram bot built with Node.js + TypeScript and grammY. It draws cards from a static deck registry, calls the Basil’s Arcana API, and sends readings to users with card images stored locally in this repo.

## Features
- Language selection: EN / RU / KZ (kk)
- 1-card and 3-card spreads
- Card images served from local assets in the container
- Uses Railway secrets for tokens and API keys

## Environment variables (Railway)
Set these in Railway **Secrets**:
- `TELEGRAM_BOT_TOKEN` (required)
- `API_BASE_URL` (default: `https://api.basilarcana.com`)
- `BASIL_ARCANA_API_KEY` (required, or legacy `ARCANA_API_KEY`)
- `DEFAULT_LOCALE` (`en`, `ru`, or `kk`)
- `BOT_ASSETS_ROOT` (optional override for assets path, defaults to `/app/assets` in Docker)

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
export BASIL_ARCANA_API_KEY=...
export API_BASE_URL=https://api.basilarcana.com
export DEFAULT_LOCALE=en
export BOT_ASSETS_ROOT=/absolute/path/to/bot/assets
npm run dev
```

## Local production run
From this `bot/` folder:

```bash
npm install
npm run build
TELEGRAM_BOT_TOKEN=... BASIL_ARCANA_API_KEY=... node dist/index.js
```

If your assets live somewhere else, set `BOT_ASSETS_ROOT` to the folder that contains `cards/`.

## Railway deployment
- Set the above secrets in Railway.
- Build command: `cd bot && npm ci && npm run build`
- Start command: `cd bot && npm run start`

## Assets
The bot resolves exact filenames from the local assets directory and sends
WEBP images directly to Telegram.
