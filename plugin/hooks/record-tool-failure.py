#!/usr/bin/env python3
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import otlp

MAX_ERROR_CHARS = 1500
MAX_COMMAND_CHARS = 300


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return
    tool_input = payload.get("tool_input") or {}
    otlp.emit("tool_failure", {
        "session.id": payload.get("session_id", ""),
        "tool_use_id": payload.get("tool_use_id", ""),
        "tool_name": payload.get("tool_name", ""),
        "command": str(tool_input.get("command") or tool_input.get("file_path") or "")[:MAX_COMMAND_CHARS],
        "error": str(payload.get("error", ""))[:MAX_ERROR_CHARS],
        "is_interrupt": str(payload.get("is_interrupt", "")),
    })


if __name__ == "__main__":
    main()
    sys.exit(0)
