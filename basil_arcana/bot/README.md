# Basil Arcana Telegram Bot

Lightweight Telegram launcher bot built with Node.js + TypeScript and grammY.
It only opens the Basil’s Arcana Telegram Mini App.

## Features
- Localized welcome message: EN / RU / KZ (kk)
- WebApp button that opens the Telegram Mini App
- `/health` command for quick checks

## Environment variables (Railway)
Set these in Railway **Secrets**:
- `TELEGRAM_BOT_TOKEN` (required)
- `TELEGRAM_WEBAPP_URL` (required, https URL of the webapp service)
- `DEFAULT_LOCALE` (`en`, `ru`, or `kk`, optional)

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
export TELEGRAM_WEBAPP_URL=https://your-webapp-domain
export DEFAULT_LOCALE=en
npm run dev
```

## Railway deployment
- Set the above secrets in Railway.
- Build command: `cd bot && npm ci && npm run build`
- Start command: `cd bot && npm run start`
