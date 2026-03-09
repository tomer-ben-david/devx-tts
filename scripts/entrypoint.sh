#!/bin/sh
set -eu

if [ -z "${DEVX_API_KEY:-}" ]; then
  echo "DEVX_API_KEY is required" >&2
  exit 1
fi

envsubst < /etc/caddy/Caddyfile.template > /etc/caddy/Caddyfile

exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
