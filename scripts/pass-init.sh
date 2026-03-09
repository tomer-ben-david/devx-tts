#!/usr/bin/env bash
set -euo pipefail

PASS_SHARED_ENTRY="${PASS_SHARED_ENTRY:-infra/ghcr/shared}"
PASS_APP_ENTRY="${PASS_APP_ENTRY:-apps/devx-tts/prod}"

if ! command -v pass >/dev/null 2>&1; then
  echo "ERROR: 'pass' CLI not found in PATH." >&2
  exit 1
fi

if pass show "${PASS_SHARED_ENTRY}" >/dev/null 2>&1; then
  echo "Pass entry already exists: ${PASS_SHARED_ENTRY}"
else
  cat <<'EOF' | pass insert -m "${PASS_SHARED_ENTRY}"
GHCR_USERNAME=
GHCR_TOKEN=
EOF
  echo "Created pass entry: ${PASS_SHARED_ENTRY}"
fi

if pass show "${PASS_APP_ENTRY}" >/dev/null 2>&1; then
  echo "Pass entry already exists: ${PASS_APP_ENTRY}"
else
  cat <<'EOF' | pass insert -m "${PASS_APP_ENTRY}"
CONTABO_VM_IP=
TTS_DOMAIN=
DEVX_API_KEY=
HF_TOKEN=
KOKORO_RESTART_API_KEY=
EOF
  echo "Created pass entry: ${PASS_APP_ENTRY}"
fi

echo
echo "Next:"
echo "1) Edit values:"
echo "   pass edit ${PASS_SHARED_ENTRY}"
echo "   pass edit ${PASS_APP_ENTRY}"
echo "2) Generate .env.local:"
echo "   ./scripts/env-sync.sh"