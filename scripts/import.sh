#!/usr/bin/env bash
# Imports credential placeholders and the workflows from ./workflows into the running n8n, then activates them.
set -euo pipefail
export MSYS_NO_PATHCONV=1  # Git Bash on Windows: keep container paths like /workflows as they are
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

# Postgres credential for the project database, generated from .env (gitignored)
cat > credentials/postgres.local.json <<JSON
[{ "id": "pgAssistantDb001", "name": "Assistant DB (Postgres)", "type": "postgres",
   "data": { "host": "postgres", "port": 5432, "database": "${ASSISTANT_DB}", "user": "${POSTGRES_USER}",
             "password": "${POSTGRES_PASSWORD}", "ssl": "disable", "allowUnauthorizedCerts": false } }]
JSON

n8n() { docker compose exec -T n8n n8n "$@"; }
[ -f credentials/.stubs-imported ] || { n8n import:credentials --input=/credentials/stubs.json && touch credentials/.stubs-imported; }
n8n import:credentials --input=/credentials/postgres.local.json

# Secrets typed into .env by the user: same ids as the placeholders, so every node stays linked
# Only once (re-importing would erase the Google sign-in tokens). Force with: FORCE_SECRETS=1 ./scripts/import.sh
if [ -n "${DISCORD_BOT_TOKEN:-}${OPENROUTER_API_KEY:-}${GOOGLE_OAUTH_CLIENT_ID:-}" ] && { [ ! -f credentials/.secrets-imported ] || [ -n "${FORCE_SECRETS:-}" ]; }; then
  python - <<'PY'
import json, os
e = os.environ.get
creds = []
if e('DISCORD_BOT_TOKEN'):
    creds.append({"id": "AOHwJRZXdD5IQR6Q", "name": "Discord Bot Auth", "type": "httpHeaderAuth",
                  "data": {"name": "Authorization", "value": "Bot " + e('DISCORD_BOT_TOKEN')}})
if e('OPENROUTER_API_KEY'):
    creds.append({"id": "wPkyL88ebUKInVNS", "name": "OpenRouter account 2", "type": "openRouterApi",
                  "data": {"apiKey": e('OPENROUTER_API_KEY')}})
if e('GOOGLE_OAUTH_CLIENT_ID'):
    g = {"clientId": e('GOOGLE_OAUTH_CLIENT_ID'), "clientSecret": e('GOOGLE_OAUTH_CLIENT_SECRET', '')}
    creds.append({"id": "24oEElfOZuhZnB8Q", "name": "Google Drive account", "type": "googleDriveOAuth2Api", "data": dict(g)})
    creds.append({"id": "97KadA1seJflRq1N", "name": "Google Docs account", "type": "googleDocsOAuth2Api", "data": dict(g)})
json.dump(creds, open("credentials/secrets.local.json", "w"))
PY
  n8n import:credentials --input=/credentials/secrets.local.json
  rm -f credentials/secrets.local.json
  touch credentials/.secrets-imported
fi
n8n import:workflow --separate --input=/workflows
for id in xrabiaYTkTTQjDY4 C3Ew0OtmltX5dMDE BuBLvhHQEfmDExIe qGOZbSYnXWg9CR0O; do
  n8n publish:workflow --id="$id" || n8n update:workflow --id="$id" --active=true
done
docker compose restart n8n >/dev/null
echo "Workflows imported and activated."
