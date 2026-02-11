# Basil Arcana Telegram Bot

Telegram bot built with Node.js + TypeScript and grammY. It provides a localized menu, opens the Basil’s Arcana Telegram Mini App, and shows subscription plans.

## Features
- On first `/start`, bot asks preferred language (`ru`/`kz`/`en`) with flag buttons
- `/start` and `/help` then use the selected language for menu and content
- Plan options are available directly in the bot, even before opening the mini app
- Telegram Stars payments for:
  - One detailed reading
  - Weekly, monthly, yearly subscription
- After successful payment user gets a unique 6-digit code and instructions to send it to Sofia
- Bot sends Sofia purchase notification with user details, plan and validity date
- Active subscription durations are summed on repeated purchases
- If user has active subscriptions, main menu shows a dedicated "My active subscriptions" button
- Sofia can manage subscriptions using bot commands:
  - `/subs` — list users with active subscriptions
  - `/sub_done <user_id>` — complete one single reading (or close active timed subscription)
- Graceful fallback if the web app URL is missing

## Environment variables (Railway)
Set these in Railway **Secrets**:
- `TELEGRAM_BOT_TOKEN` (required)
- `TELEGRAM_WEBAPP_URL` (optional, required only for the Launch app button)
- `SOFIA_CHAT_ID` (optional, enables auto-notifications to Sofia on purchase)
- `SOFIA_NOTIFY_CHAT_ID` (optional alias for `SOFIA_CHAT_ID`)
- `APP_VERSION` (optional, defaults to `dev`)
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
export APP_VERSION=2026-02-08-1
npm run dev
```

## Railway deployment
- Set the above secrets in Railway.
- Build command: `cd bot && npm ci && npm run build`
- Start command: `cd bot && npm run start`
