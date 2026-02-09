#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:3000}"
REQUEST_ID="smoke-telegram-initdata-$(date +%s)"

echo "== Missing initData in body and header (expect missing_initData) =="
curl -sS -X POST "${BASE_URL}/api/reading/generate_web?mode=fast" \
  -H "Content-Type: application/json" \
  -H "x-request-id: ${REQUEST_ID}-missing" \
  -d '{"payload":{"question":"test","spread":{"id":"single","name":"Single","positions":[{"id":"p1","title":"Focus"}]},"cards":[{"positionId":"p1","positionTitle":"Focus","cardId":"c1","cardName":"Test","keywords":["one"],"meaning":{"general":"g","light":"l","shadow":"s","advice":"a"}}],"tone":"neutral","language":"en","responseFormat":"strict_json","responseConstraints":{"tldrMaxChars":180,"sectionMaxChars":280,"actionMaxChars":160}}}' \
  | jq .

echo "== initData via header (expect invalid_initData with fake value) =="
curl -sS -X POST "${BASE_URL}/api/reading/generate_web?mode=fast" \
  -H "Content-Type: application/json" \
  -H "x-request-id: ${REQUEST_ID}-header" \
  -H "X-Telegram-InitData: fake_initdata" \
  -d '{"payload":{"question":"test","spread":{"id":"single","name":"Single","positions":[{"id":"p1","title":"Focus"}]},"cards":[{"positionId":"p1","positionTitle":"Focus","cardId":"c1","cardName":"Test","keywords":["one"],"meaning":{"general":"g","light":"l","shadow":"s","advice":"a"}}],"tone":"neutral","language":"en","responseFormat":"strict_json","responseConstraints":{"tldrMaxChars":180,"sectionMaxChars":280,"actionMaxChars":160}}}' \
  | jq .

echo "== initData via body (expect invalid_initData with fake value) =="
curl -sS -X POST "${BASE_URL}/api/reading/generate_web?mode=fast" \
  -H "Content-Type: application/json" \
  -H "x-request-id: ${REQUEST_ID}-body" \
  -d '{"initData":"fake_initdata","payload":{"question":"test","spread":{"id":"single","name":"Single","positions":[{"id":"p1","title":"Focus"}]},"cards":[{"positionId":"p1","positionTitle":"Focus","cardId":"c1","cardName":"Test","keywords":["one"],"meaning":{"general":"g","light":"l","shadow":"s","advice":"a"}}],"tone":"neutral","language":"en","responseFormat":"strict_json","responseConstraints":{"tldrMaxChars":180,"sectionMaxChars":280,"actionMaxChars":160}}}' \
  | jq .
