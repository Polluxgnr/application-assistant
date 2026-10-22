#!/usr/bin/env bash
# From a fresh clone to a running bot: creates .env, starts the stack, imports everything, prints the tunnel URL.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f .env ]; then
  cp .env.example .env
  sed -i "s/^N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$(openssl rand -hex 24)/; s/^POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$(openssl rand -hex 16)/" .env
  echo "Created .env with random secrets. Fill in the Discord and Google values, then run this script again."
  exit 0
fi
docker compose up -d
echo -n "Waiting for n8n to be healthy"
until [ "$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q n8n)")" = "healthy" ]; do echo -n "."; sleep 3; done; echo
./scripts/import.sh
sleep 5
./scripts/tunnel-url.sh || true
echo "Open http://localhost:5678"
