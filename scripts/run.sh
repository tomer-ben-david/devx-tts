#!/usr/bin/env bash
set -euo pipefail

IMAGE="${DEVX_TTS_IMAGE:-ghcr.io/remsky/kokoro-fastapi-cpu:latest}"
PORT="${DEVX_TTS_PORT:-8880}"

exec docker run --rm --name devx-tts-core -p "${PORT}:8880" "${IMAGE}"
