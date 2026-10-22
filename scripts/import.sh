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
n8n import:credentials --input=/credentials/stubs.json
n8n import:credentials --input=/credentials/postgres.local.json
n8n import:workflow --separate --input=/workflows
for id in xrabiaYTkTTQjDY4 C3Ew0OtmltX5dMDE BuBLvhHQEfmDExIe qGOZbSYnXWg9CR0O; do
  n8n publish:workflow --id="$id" || n8n update:workflow --id="$id" --active=true
done
docker compose restart n8n >/dev/null
echo "Workflows imported and activated."
