FROM caddy:builder AS builder

# Build Caddy with rate_limit module
RUN xcaddy build --with github.com/mholt/caddy-ratelimit

FROM caddy:2.7.6-alpine

# Copy custom Caddy with rate_limit from builder
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

RUN apk add --no-cache gettext

WORKDIR /app

COPY Caddyfile.template /etc/caddy/Caddyfile.template
COPY scripts/entrypoint.sh /usr/bin/entrypoint.sh
RUN chmod +x /usr/bin/entrypoint.sh

EXPOSE 8080
ENTRYPOINT ["/usr/bin/entrypoint.sh"]
