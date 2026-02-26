# Astro Web (standalone service)

Separate astrology web app for `app.basilarcana.com`.

This folder is intentionally independent from:
- `landing/`
- `server/` (API + Telegram web app backend)
- `app_flutter/` miniapp bundle

## Local run

```bash
cd astro_web
npm install
npm start
```

Open:
- `http://localhost:8080/`
- `http://localhost:8080/health`
- `http://localhost:8080/api/contracts`

## Current MVP (v1)

- Onboarding: profile capture (name, birth date/time/city/timezone) via session API
- Natal route: `/natal-chart` (astronomical chart + interpretation layer)
- Daily route: `/daily` (focus/risk/step card)
- Friends route: `/friends` (save friends + compatibility-lite score + advice)
- Session cookie: `astro_sid` (HttpOnly, SameSite=Lax)
- Natal engine now uses astronomical calculations (`circular-natal-horoscope-js`, Placidus, Tropical)
- Birth city is geocoded to `latitude/longitude` (Open-Meteo geocoding API) when coordinates are missing

### API endpoints

- `GET /api/auth/status`
- `POST /api/auth/telegram-widget`
- `POST /api/auth/telegram-init-data`
- `POST /api/auth/logout`
- `GET /api/profile`
- `PUT /api/profile`
- `GET /api/friends`
- `POST /api/friends`
- `GET /api/contracts`
- `GET /api/dashboard?period=week|month|year`
- `POST /api/natal-report`
- `POST /api/daily-insight`
- `POST /api/compatibility-report`

## Railway deploy (separate service)

1. Create a new Railway service from this repo.
2. Set **Root Directory** to `basil_arcana/astro_web`.
3. Build command: `npm install`
4. Start command: `npm start`
5. Add environment variable:
   - `DATABASE_URL` (recommended, enables persistent sessions in Postgres)
   - `TELEGRAM_BOT_TOKEN` (enables Telegram auth verification and auth gate)
   - `TELEGRAM_BOT_USERNAME` (required for Telegram Login Widget on `/login`)
   - `AUTH_REQUIRED=true` (optional explicit flag; auth also becomes required automatically when bot token is set)
6. Add custom domain: `app.basilarcana.com`
7. In GoDaddy DNS add:
   - `CNAME` name `app` value `<railway-target>.up.railway.app`
   - `TXT` name `_railway-verify.app` value `railway-verify-...` (exact value from Railway)

## Checks after deploy

```bash
dig +short app.basilarcana.com CNAME
dig +short TXT _railway-verify.app.basilarcana.com
curl -sS https://app.basilarcana.com/health
curl -sS https://app.basilarcana.com/api/profile
openssl s_client -connect app.basilarcana.com:443 -servername app.basilarcana.com </dev/null 2>/dev/null | openssl x509 -noout -ext subjectAltName
```

Expected SAN includes `DNS:app.basilarcana.com`.

`/health` now includes `dbEnabled`:
- `true` when `DATABASE_URL` is configured and table `astro_web_sessions` is active
- `false` when running in in-memory fallback mode
