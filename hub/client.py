import http.client
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

HUB_URL = os.environ.get("AI_SETUP_HUB_URL", "").rstrip("/")
CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
KEY_FILE = Path(os.environ.get("AI_SETUP_HUB_KEY_FILE") or CONFIG_HOME / "ai-setup" / "hub-observer-key")
TOOL_PREFIX = "hub_"
REQUEST_TIMEOUT_SECONDS = 30
JSON_RPC_INTERNAL_ERROR = -32603


class HubUnreachable(Exception):
    pass


def observer_key():
    try:
        key = KEY_FILE.read_text().strip()
    except OSError as error:
        raise HubUnreachable(f"cannot read the hub observer key at {KEY_FILE}: {error.strerror}") from error
    if not key or any(character.isspace() for character in key):
        raise HubUnreachable(f"the hub observer key at {KEY_FILE} must be one line without spaces")
    return key


def send(message):
    if not HUB_URL:
        raise HubUnreachable("AI_SETUP_HUB_URL is not set on this host")
    request = urllib.request.Request(
        HUB_URL + "/hub/mcp",
        data=json.dumps(message).encode(),
        headers={"Content-Type": "application/json", "Authorization": "Bearer " + observer_key()},
    )
    try:
        with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            body = response.read()
    except urllib.error.HTTPError as error:
        raise HubUnreachable(f"the hub answered {error.code}: {error.read().decode(errors='replace')[:300]}") from error
    except (OSError, http.client.HTTPException) as error:
        raise HubUnreachable(f"cannot reach the hub at {HUB_URL}: {error}") from error
    return json.loads(body) if body else None


def ask(method, params):
    reply = send({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})
    if reply is None or "error" in reply:
        raise HubUnreachable(f"the hub refused {method}: {(reply or {}).get('error')}")
    return reply["result"]


def tool_name(short_name):
    name = short_name.replace("-", "_")
    return name if name.startswith(TOOL_PREFIX) else TOOL_PREFIX + name


def typed(value):
    try:
        return json.loads(value)
    except ValueError:
        return value


def tool_arguments(pairs):
    arguments = {}
    for pair in pairs:
        name, separator, value = pair.partition("=")
        if not separator:
            raise SystemExit(f"expected name=value, got: {pair}")
        arguments[name] = typed(value)
    return arguments


def print_tools():
    for tool in ask("tools/list", {})["tools"]:
        accepted = ", ".join(tool["inputSchema"].get("properties", {}))
        print(f"{tool['name'].removeprefix(TOOL_PREFIX):<16} {tool['description']}" + (f" [{accepted}]" if accepted else ""))


def print_tool_result(short_name, pairs):
    result = ask("tools/call", {"name": tool_name(short_name), "arguments": tool_arguments(pairs)})
    for part in result.get("content", []):
        print(part.get("text", ""))
    return 1 if result.get("isError") else 0


def relay_stdio_to_hub():
    for line in sys.stdin:
        if not line.strip():
            continue
        message = json.loads(line)
        try:
            reply = send(message)
        except HubUnreachable as error:
            reply = {"jsonrpc": "2.0", "id": message.get("id"), "error": {"code": JSON_RPC_INTERNAL_ERROR, "message": str(error)}}
        expects_reply = "id" in message
        if reply is not None and expects_reply:
            print(json.dumps(reply), flush=True)


def main(arguments):
    if arguments[:1] == ["--mcp"]:
        relay_stdio_to_hub()
        return 0
    try:
        if not arguments:
            print_tools()
            return 0
        return print_tool_result(arguments[0], arguments[1:])
    except HubUnreachable as error:
        print(f"ai-setup: error: {error}", file=sys.stderr)
        return 1


sys.exit(main(sys.argv[1:]))
