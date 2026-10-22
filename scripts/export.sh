#!/usr/bin/env bash
# Exports the workflows from n8n back into ./workflows (run before every commit that changes a workflow).
set -euo pipefail
export MSYS_NO_PATHCONV=1  # Git Bash on Windows: keep container paths like /workflows as they are
cd "$(dirname "$0")/.."
docker compose exec -T n8n sh -c 'rm -rf /tmp/export && mkdir -p /tmp/export && n8n export:workflow --all --separate --pretty --output=/tmp/export/' >/dev/null
declare -A names=(
  [6Cy0U9WN3YmH5MAn]=0-setup-register-commands [qGOZbSYnXWg9CR0O]=1-main-discord-router
  [C3Ew0OtmltX5dMDE]=2-sub-analyzer [BuBLvhHQEfmDExIe]=3-sub-generator [xrabiaYTkTTQjDY4]=4-error-handler
  [InspectDbView001]=5-inspect-database
)
for id in "${!names[@]}"; do
  docker compose exec -T n8n cat "/tmp/export/$id.json" > "workflows/${names[$id]}.json"
done
echo "Exported to ./workflows. Review with: git diff --stat"
