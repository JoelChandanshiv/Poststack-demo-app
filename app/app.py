"""
Minimal dummy app for verifying the PostStack infrastructure end to end -
now with a simple Bedrock-backed chatbot to prove the app server can reach
Bedrock via its IAM role.

Routes:
  GET  /health -> 200 {"status": "ok"} - matches the ALB target group's
                  health_check_path
  GET  /       -> HTML page with a small chat box (calls /chat via fetch)
  POST /chat   -> {"message": "..."} in, {"reply": "..."} out - calls
                  Amazon Bedrock (Titan Text Express by default)
"""
import http.server
import json
import os
import socket
import socketserver
from datetime import datetime, timezone

import boto3

PORT = int(os.environ.get("APP_PORT", "8080"))
ENVIRONMENT = os.environ.get("ENVIRONMENT", "unknown")
BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "ap-south-2")
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "amazon.titan-text-express-v1")

bedrock_client = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._respond_json(200, {"status": "ok"})
            return

        self._respond_html(200, self._render_index())

    def do_POST(self):
        if self.path == "/chat":
            self._handle_chat()
            return

        self._respond_json(404, {"error": "not found"})

    def _handle_chat(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw_body = self.rfile.read(length) if length else b"{}"
            payload = json.loads(raw_body or b"{}")
            user_message = (payload.get("message") or "").strip()
        except (ValueError, json.JSONDecodeError):
            self._respond_json(400, {"error": "invalid JSON body"})
            return

        if not user_message:
            self._respond_json(400, {"error": "message is required"})
            return

        try:
            reply = self._call_bedrock(user_message)
        except Exception as e:
            # Deliberately surfaces the raw error rather than swallowing
            # it - this is a demo app, and an opaque 500 makes diagnosing
            # a missing "Model access" grant or an IAM gap much harder.
            self._respond_json(502, {"error": f"Bedrock call failed: {e}"})
            return

        self._respond_json(200, {"reply": reply})

    def _call_bedrock(self, user_message):
        # Converse is Bedrock's unified API - same request/response shape
        # regardless of which model is behind it, unlike invoke_model where
        # every model family has its own JSON schema. Authorized by the
        # same bedrock:InvokeModel / InvokeModelWithResponseStream actions
        # already granted to this role - no separate "Converse" IAM action
        # exists.
        response = bedrock_client.converse(
            modelId=BEDROCK_MODEL_ID,
            messages=[
                {"role": "user", "content": [{"text": user_message}]}
            ],
            inferenceConfig={
                "maxTokens": 512,
                "temperature": 0.7,
                "topP": 0.9,
            },
        )
        return response["output"]["message"]["content"][0]["text"].strip()

    def _render_index(self):
        hostname = socket.gethostname()
        now = datetime.now(timezone.utc).isoformat()
        return f"""<!DOCTYPE html>
<html>
<head>
  <title>PostStack - {ENVIRONMENT}</title>
  <style>
    body {{ font-family: sans-serif; padding: 2rem; max-width: 640px; margin: 0 auto; }}
    #chat-log {{ border: 1px solid #ccc; border-radius: 8px; padding: 1rem; min-height: 200px; margin-bottom: 1rem; white-space: pre-wrap; }}
    #chat-form {{ display: flex; gap: 0.5rem; }}
    #chat-input {{ flex: 1; padding: 0.5rem; }}
    .msg-user {{ color: #06c; font-weight: bold; }}
    .msg-bot {{ color: #333; }}
  </style>
</head>
<body>
  <h1>PostStack dummy app is running</h1>
  <p><strong>Environment:</strong> {ENVIRONMENT}</p>
  <p><strong>Container hostname:</strong> {hostname}</p>
  <p><strong>Server time (UTC):</strong> {now}</p>

  <h2>Bedrock chatbot demo</h2>
  <div id="chat-log"></div>
  <form id="chat-form">
    <input id="chat-input" type="text" placeholder="Ask something..." autocomplete="off" />
    <button type="submit">Send</button>
  </form>

  <script>
    const log = document.getElementById('chat-log');
    const form = document.getElementById('chat-form');
    const input = document.getElementById('chat-input');

    function append(cls, label, text) {{
      const p = document.createElement('div');
      p.className = cls;
      p.textContent = label + text;
      log.appendChild(p);
      log.scrollTop = log.scrollHeight;
    }}

    form.addEventListener('submit', async (e) => {{
      e.preventDefault();
      const message = input.value.trim();
      if (!message) return;
      append('msg-user', 'You: ', message);
      input.value = '';

      try {{
        const res = await fetch('/chat', {{
          method: 'POST',
          headers: {{ 'Content-Type': 'application/json' }},
          body: JSON.stringify({{ message }})
        }});
        const data = await res.json();
        if (res.ok) {{
          append('msg-bot', 'Bot: ', data.reply);
        }} else {{
          append('msg-bot', 'Error: ', data.error || 'unknown error');
        }}
      }} catch (err) {{
        append('msg-bot', 'Error: ', err.message);
      }}
    }});
  </script>
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
        print(f"Listening on 0.0.0.0:{PORT}, ENVIRONMENT={ENVIRONMENT}, BEDROCK_MODEL_ID={BEDROCK_MODEL_ID}")
        httpd.serve_forever()
