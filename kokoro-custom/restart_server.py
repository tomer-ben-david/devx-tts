#!/usr/bin/env python3
"""
Simple HTTP server for restarting the Kokoro container.
When /restart is called, sends SIGTERM to supervisord (PID 1) to trigger container restart.
"""
import http.server
import socketserver
import os
import sys
import signal
import time
import logging

PORT = int(os.environ.get('RESTART_SERVER_PORT', '8881'))
API_KEY = os.environ.get('RESTART_API_KEY', '')

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RestartHandler(http.server.BaseHTTPRequestHandler):
    """Handle HTTP requests for container restart."""

    def log_message(self, format, *args):
        """Override to use our logger."""
        logger.info(f"{self.address_string()} - {format % args}")

    def do_POST(self):
        """Handle POST requests."""
        if self.path == '/restart':
            # Check API key if configured
            if API_KEY:
                provided_key = self.headers.get('X-Api-Key', '')
                if provided_key != API_KEY:
                    self.send_response(401)
                    self.end_headers()
                    self.wfile.write(b'Unauthorized')
                    logger.warning("Unauthorized restart attempt")
                    return

            logger.info("Restart triggered - sending SIGTERM to supervisord (PID 1)")
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Restarting container...')

            # Ensure response is sent before killing supervisord
            self.wfile.flush()

            # Small delay to ensure response reaches client
            time.sleep(0.1)

            # Send SIGTERM to PID 1 (supervisord), which will terminate the container
            # Docker's restart policy will then automatically restart it
            os.kill(1, signal.SIGTERM)

        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

    def do_GET(self):
        """Handle GET requests - health check."""
        if self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'ok')
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')


def main():
    """Start the restart server."""
    logger.info(f"Starting restart server on port {PORT}")
    logger.info(f"API key required: {bool(API_KEY)}")

    class SocketServer(socketserver.TCPServer):
        allow_reuse_address = True

    with SocketServer(("", PORT), RestartHandler) as httpd:
        logger.info(f"Restart server running at http://0.0.0.0:{PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            logger.info("Shutting down restart server")
            httpd.shutdown()


if __name__ == '__main__':
    main()
