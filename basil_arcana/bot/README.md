# Basil Arcana Telegram Bot

Minimal Telegram bot built with Node.js + TypeScript and grammY. It draws cards locally from the Flutter assets, calls the Basil’s Arcana API, and sends readings to users.

## Features
- Language selection: EN / RU / KZ (kk)
- 1-card and 3-card spreads
- Card images served from local assets (with WEBP → PNG fallback via sharp)
- Uses Railway secrets for tokens and API keys

## Environment variables (Railway)
Set these in Railway **Secrets**:
- `TELEGRAM_BOT_TOKEN` (required)
- `API_BASE_URL` (default: `https://api.basilarcana.com`)
- `ARCANA_API_KEY` (required)
- `DEFAULT_LOCALE` (`en`, `ru`, or `kk`)

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
npm run dev
```

## Railway deployment
- Set the above secrets in Railway.
- Build command: `npm run build`
- Start command: `npm start`
- Ensure the service working directory is `bot/`.

## Assets
The bot reads card data and images from the Flutter app assets:
- `../app_flutter/assets/data/cards_*.json`
- `../app_flutter/assets/cards/*/*.webp`
- `../app_flutter/assets/deck/cover.webp`

If a card image is missing, the bot falls back to the deck cover.
