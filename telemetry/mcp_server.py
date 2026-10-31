import json
import subprocess
import sys
from pathlib import Path

REPORTS = sorted(path.stem for path in (Path(__file__).parent / "reports").glob("*.sql"))

SCHEMA_SQL = """
SELECT table, name AS column, type
FROM system.columns
WHERE database = 'ai'
ORDER BY table, position
"""

TOOLS = [
    {
        "name": "telemetry_report",
        "description": "Run a canned report on fleet agent usage. Start here for tokens, cost, cache, tools, skills, sessions or failures.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string", "enum": REPORTS},
                "days": {"type": "integer", "minimum": 1, "default": 7},
            },
            "required": ["name"],
        },
    },
    {
        "name": "telemetry_schema",
        "description": "List the ai.* analysis views and their columns before writing a custom query.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "telemetry_query",
        "description": "Run read-only ClickHouse SQL over the ai.* views or the raw otel.* tables. Returns tab-separated rows, 5000 at most.",
        "inputSchema": {
            "type": "object",
            "properties": {"sql": {"type": "string"}},
            "required": ["sql"],
        },
    },
]


def ai_setup(*args):
    result = subprocess.run(["ai-setup", *args], capture_output=True, text=True)
    failed = result.returncode != 0
    return (result.stdout + result.stderr if failed else result.stdout), failed


def call_tool(name, arguments):
    if name == "telemetry_report":
        return ai_setup("report", arguments["name"], str(arguments.get("days", 7)))
    if name == "telemetry_schema":
        return ai_setup("query", SCHEMA_SQL)
    if name == "telemetry_query":
        return ai_setup("query", arguments["sql"])
    return f"unknown tool {name}", True


def handle(method, params):
    if method == "initialize":
        return {
            "protocolVersion": params.get("protocolVersion", "2025-06-18"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "ai-setup-telemetry", "version": "1"},
        }
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        text, failed = call_tool(params["name"], params.get("arguments", {}))
        return {"content": [{"type": "text", "text": text}], "isError": failed}
    return None


def main():
    for line in sys.stdin:
        message = json.loads(line)
        if "id" not in message:
            continue
        result = handle(message.get("method"), message.get("params", {}))
        reply = {"jsonrpc": "2.0", "id": message["id"]}
        if result is None:
            reply["error"] = {"code": -32601, "message": "method not found"}
        else:
            reply["result"] = result
        print(json.dumps(reply), flush=True)


if __name__ == "__main__":
    main()
