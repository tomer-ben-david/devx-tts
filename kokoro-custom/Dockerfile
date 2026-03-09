# Extend the official kokoro-fastapi-cpu image
FROM ghcr.io/remsky/kokoro-fastapi-cpu:latest

# Install supervisord (run as root to install packages)
USER root
RUN apt-get update && \
    apt-get install -y supervisor && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create log directory for supervisord and set ownership
RUN mkdir -p /var/log/supervisor && \
    chown -R appuser:appuser /var/log/supervisor

# Copy restart server and supervisord config
COPY restart_server.py /app/restart_server.py
COPY supervisord.conf /etc/supervisord.conf

# Make files readable/executable by appuser
RUN chown appuser:appuser /app/restart_server.py && \
    chmod +x /app/restart_server.py && \
    chmod a+r /etc/supervisord.conf

# Switch back to appuser for running processes
USER appuser

# Override the original entrypoint to use supervisord
# This will run both FastAPI (port 8880) and restart server (port 8881)
ENTRYPOINT []
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
