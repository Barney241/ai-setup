import json
import os
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).parent
SCOPE = (HERE / "scope.sql").read_text()
PANELS = {path.stem: SCOPE + path.read_text() for path in (HERE / "panels").glob("*.sql")}
PAGE = (HERE / "dashboard.html").read_bytes()
ALLOWED_DAYS = {"7", "14", "30"}
TEXT_FILTERS = ("project", "host", "agent", "session", "kind", "name")
MAX_FILTER_LENGTH = 300
MAX_CACHE_ENTRIES = 1000
CACHE_SECONDS = 30

listen_addresses = os.environ["DASHBOARD_ADDRESSES"].split()
listen_port = int(os.environ["DASHBOARD_PORT"])
clickhouse_url = os.environ["DASHBOARD_CLICKHOUSE_URL"]
cache = {}


def run_panel(name, filters):
    key = (name, tuple(sorted(filters.items())))
    cached = cache.get(key)
    if cached and time.monotonic() - cached[0] < CACHE_SECONDS:
        return cached[1]
    params = urllib.parse.urlencode(
        {
            "user": "agent",
            "default_format": "JSON",
            "output_format_json_quote_64bit_integers": 0,
            **{f"param_{field}": value for field, value in filters.items()},
        }
    )
    request = urllib.request.Request(f"{clickhouse_url}/?{params}", data=PANELS[name].encode())
    with urllib.request.urlopen(request, timeout=30) as response:
        rows = json.load(response)["data"]
    body = json.dumps(rows).encode()
    if len(cache) >= MAX_CACHE_ENTRIES:
        cache.clear()
    cache[key] = (time.monotonic(), body)
    return body


def parse_filters(query):
    values = urllib.parse.parse_qs(query)
    filters = {field: values.get(field, [""])[0] for field in TEXT_FILTERS}
    filters["days"] = values.get("days", ["7"])[0]
    return filters


def filters_are_valid(filters):
    within_length = all(len(filters[field]) <= MAX_FILTER_LENGTH for field in TEXT_FILTERS)
    return filters["days"] in ALLOWED_DAYS and within_length


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        if url.path == "/":
            self.respond(200, "text/html; charset=utf-8", PAGE)
            return
        name = url.path.removeprefix("/api/")
        filters = parse_filters(url.query)
        if name not in PANELS or not filters_are_valid(filters):
            self.respond(404, "text/plain", b"not found")
            return
        try:
            self.respond(200, "application/json", run_panel(name, filters))
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


servers = [ThreadingHTTPServer((address, listen_port), Handler) for address in listen_addresses]
threads = [threading.Thread(target=server.serve_forever) for server in servers]
for thread in threads:
    thread.start()
for thread in threads:
    thread.join()
