import json
import os
import signal
import socket
import time
import urllib.request

SETTINGS = os.path.expanduser("~/.claude/settings.json")

DEADLINE_SECONDS = 3


def endpoint():
    configured = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
    if configured:
        return configured
    try:
        with open(SETTINGS) as handle:
            return json.load(handle).get("env", {}).get("OTEL_EXPORTER_OTLP_ENDPOINT", "")
    except (OSError, ValueError):
        return ""


def attribute(name, value):
    return {"key": name, "value": {"stringValue": str(value)}}


def send(body, attributes):
    target = endpoint()
    if not target:
        return
    attributes = {**attributes, "t3_thread_id": os.environ.get("T3CODE_THREAD_ID", "")}
    payload = {
        "resourceLogs": [{
            "resource": {"attributes": [attribute("service.name", "ai-setup"), attribute("host.name", socket.gethostname())]},
            "scopeLogs": [{
                "logRecords": [{
                    "timeUnixNano": str(time.time_ns()),
                    "body": {"stringValue": body},
                    "attributes": [attribute(name, value) for name, value in attributes.items() if value != ""],
                }]
            }],
        }]
    }
    request = urllib.request.Request(
        f"{target}/v1/logs",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    urllib.request.urlopen(request, timeout=2).read()


def give_up(signum, frame):
    raise TimeoutError


def emit(body, attributes):
    signal.signal(signal.SIGALRM, give_up)
    signal.alarm(DEADLINE_SECONDS)
    try:
        send(body, attributes)
    except Exception:
        pass
    finally:
        signal.alarm(0)
