#!/usr/bin/env bash
# Prints the public HTTPS URL of the Cloudflare quick tunnel and the Discord endpoint to paste.
cd "$(dirname "$0")/.."
url=$(docker compose logs tunnel 2>/dev/null | grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' | tail -1)
if [ -z "$url" ]; then echo "Tunnel not ready yet: try again in a few seconds (docker compose logs tunnel)"; exit 1; fi
echo "Tunnel:                     $url"
echo "Discord Interactions URL:   $url/webhook/application-assistant"
echo "(Discord Developer Portal > your app > General Information > Interactions Endpoint URL)"
