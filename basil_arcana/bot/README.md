# Basil Arcana Telegram Bot

Launcher-only Telegram bot built with Node.js + TypeScript and grammY. It only opens the Basil’s Arcana Telegram Mini App.

## Features
- `/start` and `/help` return a button that opens the mini app
- Any other message nudges the user to open the mini app

## Environment variables (Railway)
Set these in Railway **Secrets**:
- `TELEGRAM_BOT_TOKEN` (required)
- `TELEGRAM_WEBAPP_URL` (required)
- `NODE_ENV` (optional)

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
export TELEGRAM_WEBAPP_URL=https://your-webapp.example
npm run dev
```

## Railway deployment
- Set the above secrets in Railway.
- Build command: `cd bot && npm ci && npm run build`
- Start command: `cd bot && npm run start`
