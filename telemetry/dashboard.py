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
ASSET_TYPES = {
    "tokens.css": "text/css; charset=utf-8",
    "fonts/inter.woff2": "font/woff2",
    "favicon.svg": "image/svg+xml",
}
ASSETS = {
    f"/lab-ui/{name}": (content_type, (HERE / "lab-ui" / name).read_bytes())
    for name, content_type in ASSET_TYPES.items()
}
ALLOWED_DAYS = {"7", "14", "30"}
TEXT_FILTERS = ("project", "host", "agent", "session", "kind", "name")
MAX_FILTER_LENGTH = 300
MAX_CACHE_ENTRIES = 1000
FRESH_SECONDS = 60
STALE_SECONDS = 1800
MAX_QUERY_THREADS = 4
MAX_CONCURRENT_QUERIES = 2
QUERY_TIMEOUT_SECONDS = 90

listen_addresses = os.environ["DASHBOARD_ADDRESSES"].split()
listen_port = int(os.environ["DASHBOARD_PORT"])
clickhouse_url = os.environ["DASHBOARD_CLICKHOUSE_URL"]
cache = {}
refreshing = set()
refresh_lock = threading.Lock()
query_slots = threading.BoundedSemaphore(MAX_CONCURRENT_QUERIES)


def cache_key(name, filters):
    return (name, tuple(sorted(filters.items())))


def query_panel(name, filters):
    params = urllib.parse.urlencode(
        {
            "user": "agent",
            "default_format": "JSON",
            "output_format_json_quote_64bit_integers": 0,
            "max_threads": MAX_QUERY_THREADS,
            **{f"param_{field}": value for field, value in filters.items()},
        }
    )
    request = urllib.request.Request(f"{clickhouse_url}/?{params}", data=PANELS[name].encode())
    with query_slots, urllib.request.urlopen(request, timeout=QUERY_TIMEOUT_SECONDS) as response:
        rows = json.load(response)["data"]
    body = json.dumps(rows).encode()
    if len(cache) >= MAX_CACHE_ENTRIES:
        cache.clear()
    cache[cache_key(name, filters)] = (time.monotonic(), body)
    return body


def refresh_in_background(name, filters):
    key = cache_key(name, filters)
    with refresh_lock:
        if key in refreshing:
            return
        refreshing.add(key)

    def refresh():
        try:
            query_panel(name, filters)
        except (OSError, ValueError):
            pass
        finally:
            with refresh_lock:
                refreshing.discard(key)

    threading.Thread(target=refresh, daemon=True).start()


def run_panel(name, filters, fresh):
    cached = cache.get(cache_key(name, filters))
    if cached and not fresh:
        age = time.monotonic() - cached[0]
        if age < STALE_SECONDS:
            if age >= FRESH_SECONDS:
                refresh_in_background(name, filters)
            return cached[1], int(age)
    return query_panel(name, filters), 0


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
        if url.path in ASSETS:
            self.respond(200, *ASSETS[url.path])
            return
        name = url.path.removeprefix("/api/")
        filters = parse_filters(url.query)
        if name not in PANELS or not filters_are_valid(filters):
            self.respond(404, "text/plain", b"not found")
            return
        fresh = urllib.parse.parse_qs(url.query).get("fresh") == ["1"]
        try:
            body, age = run_panel(name, filters, fresh)
            self.respond(200, "application/json", body, [("X-Data-Age", str(age))])
        except OSError as error:
            self.respond(502, "text/plain", str(error).encode())

    def respond(self, status, content_type, body, extra_headers=()):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        for header, value in extra_headers:
            self.send_header(header, value)
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
