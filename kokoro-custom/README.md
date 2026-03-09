# Kokoro-FastAPI Custom Image with /restart Endpoint

This is a custom Docker image that extends [`ghcr.io/remsky/kokoro-fastapi-cpu:latest`](https://github.com/remsky/Kokoro-FastAPI) with a `/restart` endpoint to trigger container restarts via `exit(0)`.

## Why This Exists

The upstream Kokoro-FastAPI has a memory leak in the ONNX model that causes memory to grow with each TTS request (~50-100MB per call). After 30-50 requests, the container gets OOM-killed.

**Upstream Issue**: https://github.com/remsky/Kokoro-FastAPI/issues/262

## How It Works

Instead of mounting Docker sockets and running `docker restart` commands from external containers, this image provides a clean HTTP-based restart mechanism:

1. **POST /restart** - Calls `sys.exit(0)` to terminate the container
2. **Docker's `restart: always` policy** automatically restarts the container
3. **Fresh memory** - Each restart clears the accumulated memory leak

## Architecture

- **Port 8880**: Main Kokoro-FastAPI service (original functionality)
- **Port 8881**: Restart server (new)
- **Supervisord**: Manages both processes

## Files

| File | Description |
|------|-------------|
| `Dockerfile` | Extends upstream image, adds supervisord |
| `supervisord.conf` | Runs both FastAPI and restart server |
| `restart_server.py` | HTTP server with `/restart` endpoint |

## API

### POST /restart

Triggers container restart via `exit(0)`.

**Headers:**
```
X-Api-Key: <your-api-key>  # Optional, set via RESTART_API_KEY env var
```

**Response:**
```
HTTP 200
Restarting container...
```

Then the container exits(0) and Docker restarts it.

### GET /health

Health check endpoint.

**Response:**
```
HTTP 200
ok
```

## Building

```bash
cd kokoro-custom
docker build -t kokoro-fastapi-restart:latest .
```

## Usage

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `RESTART_SERVER_PORT` | `8881` | Port for restart server |
| `RESTART_API_KEY` | (empty) | Optional API key for /restart endpoint |

### Docker Run

```bash
docker run -p 8880:8880 -p 8881:8881 \
  -e RESTART_API_KEY=your-secret-key \
  --restart always \
  kokoro-fastapi-restart:latest
```

### Docker Compose

```yaml
services:
  kokoro:
    image: ghcr.io/<your-username>/kokoro-fastapi-restart:latest
    ports:
      - "8880:8880"  # Main API
      - "8881:8881"  # Restart endpoint
    environment:
      RESTART_API_KEY: your-secret-key
    restart: always
```

### Kamal (devx-tts)

The devx-tts project uses this as an accessory:

```yaml
accessories:
  devx-tts-core:
    image: <%= ENV["GHCR_USERNAME"] %>/kokoro-fastapi-restart:latest
    host: <%= ENV["CONTABO_VM_IP"] %>
    port: 8880
    restart: always
    env:
      clear:
        HF_TOKEN: <%= ENV["HF_TOKEN"] %>
        RESTART_SERVER_PORT: "8881"
        RESTART_API_KEY: <%= ENV["KOKORO_RESTART_API_KEY"] %>
```

## Calling /restart from Java

```java
HttpHeaders headers = new HttpHeaders();
headers.set("X-Api-Key", apiKey);
HttpEntity<Void> request = new HttpEntity<>(headers);

restTemplate.exchange(
    URI.create("http://kokoro:8881/restart"),
    HttpMethod.POST,
    request,
    String.class
);
```

## Benefits Over Docker Socket Approach

| Aspect | Docker Socket | /restart Endpoint |
|--------|---------------|-------------------|
| **Security** | Requires socket mount (risky) | No socket access needed |
| **Complexity** | Needs docker CLI in container | Simple HTTP call |
| **Portability** | Tightly coupled to Docker | Works with any container runtime |
| **Failure Mode** | docker CLI can fail | HTTP is reliable |

## Troubleshooting

### Container exits immediately after restart

Check supervisord logs:
```bash
docker logs <container>
```

### /restart returns 401 Unauthorized

Check that `X-Api-Key` header matches `RESTART_API_KEY` env var.

### Container not restarting

Ensure Docker has `restart: always` policy:
```bash
docker inspect <container> | grep RestartPolicy
```

## References

- Upstream: https://github.com/remsky/Kokoro-FastAPI
- Memory leak issue: https://github.com/remsky/Kokoro-FastAPI/issues/262
- devx-tts project: Uses this image for TTS service
