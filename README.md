# devx-tts

Standalone Devx TTS service (Kokoro model) for local/dev usage and production deployment. Runs the Kokoro FastAPI server and exposes an OpenAI-compatible speech endpoint.

## Architecture

- **Gateway**: Caddy reverse proxy with API key authentication
- **devx-tts-core**: Kokoro FastAPI TTS service (custom image with `/restart` endpoint)

The custom `kokoro-fastapi-restart` image extends the upstream Kokoro-FastAPI with a `/restart` endpoint to work around the ONNX memory leak. See `kokoro-custom/README.md` for details.

## Local dev

### Direct (no API key)

```bash
./scripts/run.sh
```

Or:

```bash
docker compose up
```

The service listens on `http://localhost:8880`.

### With API key gateway

```bash
./scripts/pass-init.sh
pass edit apps/devx-tts/prod
./scripts/env-sync.sh
docker compose --profile gateway up --build
```

Gateway URL: `http://localhost:8881/v1/audio/speech`

Required header:

```
X-Api-Key: your-tts-api-key
```

## Pass-driven environment sync

1. Seed your local `pass` entries:

```bash
./scripts/pass-init.sh
```

2. Edit the values in `pass`:

```bash
pass edit infra/ghcr/shared
pass edit apps/devx-tts/prod
```

3. Generate `.env.local` on demand:

```bash
./scripts/env-sync.sh
```

`.env.local` stays local and is ignored by git. No encrypted env blob is committed.

## Production deployment (Kamal)

1. Seed or update your local `pass` entries:

```bash
./scripts/pass-init.sh
```

2. Set values in `pass`:
   - `CONTABO_VM_IP`
   - `TTS_DOMAIN`
   - `GHCR_USERNAME` / `GHCR_TOKEN`
   - `DEVX_API_KEY`
   - `HF_TOKEN` (optional)

3. Generate `.env.local` from `pass`:

```bash
./scripts/env-sync.sh
```

4. Deploy:

```bash
kamal setup
kamal deploy
```

The gateway exposes:

```
https://<TTS_DOMAIN>/v1/audio/speech
```

Health check:

```
https://<TTS_DOMAIN>/health
```

## EchoSlack integration

Set the following in `2025-echoslack` (or your environment):

```
DEVX_MODE=api
DEVX_API_URL=https://<TTS_DOMAIN>/v1/audio/speech
DEVX_API_FORMAT=openai
DEVX_API_MODEL=kokoro
DEVX_API_RESPONSE_FORMAT=mp3
DEVX_API_KEY=your-tts-api-key
DEVX_API_KEY_HEADER=X-Api-Key
```

## Notes

- **Kokoro image**: `ghcr.io/remsky/kokoro-fastapi-cpu:latest` (upstream)
- **Custom image**: `ghcr.io/<your-username>/kokoro-fastapi-restart:latest` (with `/restart` endpoint for memory leak workaround)
- **Memory leak issue**: https://github.com/remsky/Kokoro-FastAPI/issues/262
- **Docs (local)**: `http://localhost:8880/docs`
- **Voices (local)**: `GET http://localhost:8880/v1/audio/voices`
- **Secrets model**: use `pass` locally, materialize `.env.local` with `./scripts/env-sync.sh`, and let runtime containers consume direct environment variables.

## Memory Leak Workaround

The upstream Kokoro-FastAPI has an ONNX memory leak that causes memory to grow with each TTS request. This custom image adds a `/restart` endpoint (port 8881) that triggers container restart via `exit(0)`. Docker's `restart: always` policy then automatically restarts the container with fresh memory.

**Before each TTS section**, the echoslack service calls:
```
POST http://kokoro:8881/restart
X-Api-Key: <your-key>
```

This eliminates the need for Docker socket mounting in the echoslack container, improving security.
