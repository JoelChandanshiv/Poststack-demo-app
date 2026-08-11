"""
Minimal dummy app for verifying the PostStack infrastructure end to end.
No dependencies (stdlib only) so the Docker image stays small and there's
nothing to pip install - the goal here is proving the ALB -> app server ->
container path works, not building a real application.

Routes:
  GET /health  -> 200 {"status": "ok"} - matches the ALB target group's
                  health_check_path (see modules/alb/variables.tf)
  GET /        -> a simple HTML page showing environment + hostname, so
                  you can visually confirm which container/instance
                  actually answered a given request
"""
import http.server
import json
import os
import socket
import socketserver
from datetime import datetime, timezone

PORT = int(os.environ.get("APP_PORT", "8080"))
ENVIRONMENT = os.environ.get("ENVIRONMENT", "unknown")


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond_json(200, {"status": "ok"})
            return

        self._respond_html(200, self._render_index())

    def _render_index(self):
        hostname = socket.gethostname()
        now = datetime.now(timezone.utc).isoformat()
        return f"""<!DOCTYPE html>
<html>
<head><title>PostStack - {ENVIRONMENT}</title></head>
<body style="font-family: sans-serif; padding: 2rem;">
  <h1>PostStack dummy app is running</h1>
  <p><strong>Environment:</strong> {ENVIRONMENT}</p>
  <p><strong>Container hostname:</strong> {hostname}</p>
  <p><strong>Server time (UTC):</strong> {now}</p>
  <p>If you're seeing this through the ALB DNS name, the full path is
     working: ALB &rarr; target group &rarr; app server &rarr; this
     container.</p>
</body>
</html>
"""

    def _respond_json(self, status, body):
        payload = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _respond_html(self, status, html):
        payload = html.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))


if __name__ == "__main__":
    with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
        print(f"Listening on 0.0.0.0:{PORT}, ENVIRONMENT={ENVIRONMENT}")
        httpd.serve_forever()
