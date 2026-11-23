#!/usr/bin/env python3
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import otlp

COMMAND_START = r"(^|[\s;&|('\"])"

LOOP = re.compile(COMMAND_START + r"(until|while|for)\s")

POLLING_SLEEP = re.compile(COMMAND_START + r"sleep\s+(\$|[5-9]|[1-9]\d)")

DETACHED_LAUNCH = re.compile(COMMAND_START + r"(setsid|nohup|systemd-run)\s")

HINT = (
    "A foreground sleep loop holds the turn and replays the whole context on every wake-up. "
    "A background Bash task re-invokes you when it exits, so never poll its output file. "
    "To wait on a detached job, have it touch a .done file and wait with one Monitor call on that file, "
    "or run the same loop with run_in_background: true. "
    "Under T3, wait on a background task with t3_background_wait."
)


def is_foreground_sleep_poll(tool_input):
    if tool_input.get("run_in_background"):
        return False
    command = tool_input.get("command") or ""
    if DETACHED_LAUNCH.search(command):
        return False
    return bool(LOOP.search(command) and POLLING_SLEEP.search(command))


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        sys.exit(0)
    if payload.get("tool_name") != "Bash":
        sys.exit(0)
    if not is_foreground_sleep_poll(payload.get("tool_input") or {}):
        sys.exit(0)
    otlp.emit("hook_block", {"session.id": payload.get("session_id", ""), "hook": "block-sleep-poll", "reason": "foreground sleep loop"})
    print("BLOCKED: a foreground polling loop with sleep.", file=sys.stderr)
    print(HINT, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
