# Sofia Worker

Standalone worker for the `Sofia Knox` AI persona.

This package is intentionally separated from the main Telegram bot so Sofia deploys cannot break the production bot service.

## Railway

Create a separate Railway service with:

- `Root Directory`: `basil_arcana/sofia_worker`
- `Build Command`: `npm ci && npm run build`
- `Start Command`: `npm run start`

## Environment

Required:

- `DATABASE_URL`

Needed for generation:

- `OPENAI_API_KEY`
- `SOFIA_AGENT_MODEL` (default: `gpt-4.1-mini`)
- `SOFIA_AGENT_NAME` (default: `Sofia Knox`)
- `SOFIA_AGENT_HANDLE` (default: `@SofiaKnoxx`)

Needed for Telegram user-session actions:

- `TELEGRAM_API_ID`
- `TELEGRAM_API_HASH`
- `SOFIA_SESSION_STRING`

Runtime tuning:

- `SOFIA_INBOX_DIALOG_LIMIT` (default: `30`)
- `SOFIA_INBOX_MESSAGE_LIMIT` (default: `8`)
- `SOFIA_INBOX_LOOKBACK_HOURS` (default: `72`)
- `SOFIA_SCHEDULER_POLL_MINUTES` (default: `15`)
- `SOFIA_SCHEDULER_SEARCH_LIMIT` (default: `12`)
- `SOFIA_GENERATION_BATCH_SIZE` (default: `5`)
- `SOFIA_AUTO_SEND_APPROVED` (default: `false`)

## Commands

Create a Telegram user session locally:

```bash
cd /Users/basilart/basil_arcana/basil_arcana/sofia_worker
TELEGRAM_API_ID=... TELEGRAM_API_HASH=... npm run sofia:create-session
```

Start the worker locally:

```bash
cd /Users/basilart/basil_arcana/basil_arcana/sofia_worker
npm install
npm run build
npm run start
```

Useful one-off commands:

```bash
npm run sofia:session-check
npm run sofia:ingest-inbox
npm run sofia:scheduler-once
npm run sofia:list-drafts
```

## Isolation rule

- Main Telegram bot service should keep using `basil_arcana/bot`
- Sofia worker service should use only `basil_arcana/sofia_worker`
- Future Sofia changes should be made in this package, not in `bot/`
