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
- Natal route: `/natal-chart` (server-driven mock report)
- Daily route: `/daily` (focus/risk/step card)
- Friends route: `/friends` (save friends + compatibility-lite score + advice)
- Session cookie: `astro_sid` (HttpOnly, SameSite=Lax)

### API endpoints

- `GET /api/profile`
- `PUT /api/profile`
- `GET /api/friends`
- `POST /api/friends`
- `GET /api/contracts`
- `POST /api/natal-report`
- `POST /api/daily-insight`
- `POST /api/compatibility-report`

## Railway deploy (separate service)

1. Create a new Railway service from this repo.
2. Set **Root Directory** to `basil_arcana/astro_web`.
3. Build command: `npm install`
4. Start command: `npm start`
5. Add custom domain: `app.basilarcana.com`
6. In GoDaddy DNS add:
   - `CNAME` name `app` value `<railway-target>.up.railway.app`
   - `TXT` name `_railway-verify.app` value `railway-verify-...` (exact value from Railway)

## Checks after deploy

```bash
dig +short app.basilarcana.com CNAME
dig +short TXT _railway-verify.app.basilarcana.com
curl -sS https://app.basilarcana.com/health
openssl s_client -connect app.basilarcana.com:443 -servername app.basilarcana.com </dev/null 2>/dev/null | openssl x509 -noout -ext subjectAltName
```

Expected SAN includes `DNS:app.basilarcana.com`.
