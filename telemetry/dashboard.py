import json
import os
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).parent
REPORTS = {path.stem: path.read_text() for path in (HERE / "reports").glob("*.sql")}
PAGE = (HERE / "dashboard.html").read_bytes()
ALLOWED_DAYS = {"7", "14", "30"}
CACHE_SECONDS = 30

listen_address = os.environ["DASHBOARD_ADDRESS"]
listen_port = int(os.environ["DASHBOARD_PORT"])
clickhouse_url = os.environ["DASHBOARD_CLICKHOUSE_URL"]
cache = {}


def run_report(name, days):
    key = (name, days)
    cached = cache.get(key)
    if cached and time.monotonic() - cached[0] < CACHE_SECONDS:
        return cached[1]
    params = urllib.parse.urlencode(
        {
            "user": "agent",
            "default_format": "JSON",
            "output_format_json_quote_64bit_integers": 0,
            "param_days": days,
        }
    )
    request = urllib.request.Request(f"{clickhouse_url}/?{params}", data=REPORTS[name].encode())
    with urllib.request.urlopen(request, timeout=30) as response:
        rows = json.load(response)["data"]
    body = json.dumps(rows).encode()
    cache[key] = (time.monotonic(), body)
    return body


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/":
            self.respond(200, "text/html; charset=utf-8", PAGE)
            return
        name = url.path.removeprefix("/api/")
        days = urllib.parse.parse_qs(url.query).get("days", ["7"])[0]
        if name not in REPORTS or days not in ALLOWED_DAYS:
            self.respond(404, "text/plain", b"not found")
            return
        try:
            self.respond(200, "application/json", run_report(name, days))
        except OSError as error:
            self.respond(502, "text/plain", str(error).encode())

    def respond(self, status, content_type, body):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


ThreadingHTTPServer((listen_address, listen_port), Handler).serve_forever()
