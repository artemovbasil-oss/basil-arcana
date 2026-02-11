# Basil's Arcana Landing

Static landing page for Railway deployment.

## Contents

- `index.html` - One-page multilingual landing (`ru`, `kz`, `en`)
- `Dockerfile` - Nginx deploy path
- `server.mjs` + `package.json` - fallback deploy path (`npm start`, listens on `$PORT`)

## Deploy on Railway

1. Create a new Railway service from this repository.
2. Set service root to `basil_arcana/landing`.
3. Preferred: set builder to Dockerfile (or let it auto-detect `Dockerfile`).
4. Deploy and open the generated public URL.
5. If Railway still chooses Nixpacks, it will run `npm start` from this folder.

## Domain mapping (safe for existing API/CDN)

- `www.basilarcana.com` should point only to this landing service.
- Keep these unchanged:
  - `api.basilarcana.com` -> Railway API service
  - `cdn.basilarcana.com` -> BunnyCDN

## Links used

- Bot: `https://t.me/tarot_arkana_bot`
- Mini app: `https://t.me/tarot_arkana_bot/app`
- Sofia: `https://t.me/SofiaKnoxx`
- Sofia media (CDN):
  - `https://cdn.basilarcana.com/sofia/sofia.webp`
  - `https://cdn.basilarcana.com/sofia/sofia.webm`
