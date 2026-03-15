# Sofia Agent

`Sofia Knox` is modeled here as an explicitly AI-authored Telegram persona for Basil Arcana. This subsystem is meant to prepare drafts for:

- tarot channel posts
- product-design guest posts
- public comments and group outreach
- direct-message replies
- natal-chart replies

## Environment

Required:

- `DATABASE_URL`

Optional but needed for generation:

- `OPENAI_API_KEY`
- `SOFIA_AGENT_MODEL` (default: `gpt-4.1-mini`)
- `SOFIA_AGENT_NAME` (default: `Sofia Knox`)
- `SOFIA_AGENT_HANDLE` (default: `@SofiaKnoxx`)

Optional but needed for Telegram user-session actions:

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

Create a task:

```bash
npm run sofia:create-task -- channel_post "Post about decision-making with tarot" --channel=@somechannel --topic=tarot --sourceText="angle for tomorrow"
```

Run one generation cycle:

```bash
npm run sofia:run-once
```

List latest drafts:

```bash
npm run sofia:list-drafts
```

Check the MTProto user session:

```bash
npm run sofia:session-check
```

Create a fresh Telegram user session locally:

```bash
TELEGRAM_API_ID=... TELEGRAM_API_HASH=... npm run sofia:create-session
```

Ingest incoming private messages into threads/tasks:

```bash
npm run sofia:ingest-inbox
```

Add a recurring discovery target:

```bash
npm run sofia:add-search-target -- "Tarot growth groups" --query="tarot spread" --chat=@somegroup --cadence=180
```

Run one search/discovery cycle:

```bash
npm run sofia:scheduler-once
```

Start the long-running scheduler daemon:

```bash
npm run sofia:scheduler
```

Approve a task and send approved drafts:

```bash
npm run sofia:approve-task -- 42
npm run sofia:send-approved
```

## Current scope

This iteration now gives us:

- persistent task queue in Postgres
- Sofia persona/system prompt
- one-shot draft generation via OpenAI
- stored drafts for review/approval
- inbox/threads ingestion for incoming Telegram private messages
- persistent thread + message storage
- search-target scheduler for recurring channel/group discovery
- MTProto user-session layer for reading dialogs, ingesting messages, and sending approved drafts

## Notes on operations

- DMs are ingested into `sofia_agent_threads` and `sofia_agent_messages`.
- New inbound messages create `dm_reply` or `natal_chart_reply` tasks automatically.
- Search targets create `channel_comment` or `group_outreach` tasks from matching messages.
- `SOFIA_AUTO_SEND_APPROVED=false` is the safe default: the scheduler drafts autonomously, but only sends tasks after approval.
- `send-approved` uses the Telegram user session, so it will post as the Sofia account rather than the bot token identity.
