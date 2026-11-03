#!/usr/bin/env python3
import json
import os
import re
import shlex
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import otlp

MAX_READ_LINES = 80

WHOLE_FILE_READERS = {"cat", "less", "more", "bat", "view", "nl", "tac", "strings", "xxd", "od"}

SLICING_READERS = {"head", "tail"}

SPLIT_OPERATORS = re.compile(r"\|\||&&|[;|&\n]")

COUNT_FLAG = re.compile(r"^-(\d+)$")

GLOB_CHARS = "*?["

PRINT_ALL_SCRIPTS = {"", "p", "1", "1,$p", "{print}", "{print$0}"}

HINT = (
    "The papercuts log is large and stays in context. Search it instead: "
    "grep -i '<symptom keyword>' ~/Projects/papercuts/<repo>.md "
    "(older entries: <repo>.archive.md), or Read with a limit of "
    f"{MAX_READ_LINES} lines or fewer."
)


SESSION = {"id": ""}


def block(what):
    otlp.emit("hook_block", {"session.id": SESSION["id"], "hook": "block-papercuts-dump", "reason": what})
    print(f"BLOCKED: {what}", file=sys.stderr)
    print(HINT, file=sys.stderr)
    sys.exit(2)


def is_papercuts_file(path):
    expanded = os.path.expanduser(path)
    return "/papercuts/" in expanded and expanded.endswith(".md")


def check_read(tool_input):
    path = tool_input.get("file_path") or ""
    if not is_papercuts_file(path):
        return
    limit = tool_input.get("limit")
    if not isinstance(limit, int) or limit > MAX_READ_LINES:
        block(f"Read of the whole papercuts file {os.path.basename(path)}.")


def tokens_of(segment):
    try:
        return shlex.split(segment)
    except ValueError:
        return segment.split()


def count_value_of(tokens, index):
    token = tokens[index]
    if re.fullmatch(r"-\d+", token):
        return token[1:]
    if token == "-n" or token == "--lines":
        return tokens[index + 1] if index + 1 < len(tokens) else ""
    if token.startswith("--lines="):
        return token[len("--lines="):]
    if token.startswith("-n"):
        return token[2:]
    return None


def line_count_of(tokens):
    count = None
    for index, token in enumerate(tokens):
        if token == "--bytes" or token.startswith(("--bytes=", "-c")):
            return None
        value = count_value_of(tokens, index)
        if value is None:
            continue
        if not value.isdigit():
            return None
        count = int(value)
    return count


def names_papercuts_target(token):
    expanded = os.path.expanduser(token)
    if "/papercuts" not in expanded:
        return False
    return expanded.endswith(".md") or any(char in expanded for char in GLOB_CHARS)


def targets_papercuts(tokens, in_papercuts_directory):
    for token in tokens[1:]:
        if token.startswith("-"):
            continue
        if names_papercuts_target(token):
            return True
        if in_papercuts_directory and (token.endswith(".md") or any(char in token for char in GLOB_CHARS)):
            return True
    return False


def enters_papercuts_directory(tokens):
    return tokens[0] in {"cd", "pushd"} and any("papercuts" in token for token in tokens[1:])


def prints_everything(reader, tokens):
    return reader in {"sed", "awk"} and any(re.sub(r"\s+", "", token) in PRINT_ALL_SCRIPTS for token in tokens[1:])


def check_bash(command):
    if "papercuts" not in command:
        return
    in_papercuts_directory = False
    for segment in SPLIT_OPERATORS.split(command):
        tokens = tokens_of(segment.strip())
        if not tokens:
            continue
        if tokens[0] in {"cd", "pushd"}:
            in_papercuts_directory = enters_papercuts_directory(tokens)
            continue
        reader = tokens[0].rsplit("/", 1)[-1]
        if not targets_papercuts(tokens, in_papercuts_directory):
            continue
        if reader in WHOLE_FILE_READERS or prints_everything(reader, tokens):
            block(f"`{reader}` of a papercuts file.")
        if reader in SLICING_READERS:
            lines = line_count_of(tokens)
            if lines is None or lines > MAX_READ_LINES:
                block(f"`{reader}` of a papercuts file without a line count of {MAX_READ_LINES} or fewer.")


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        sys.exit(0)
    tool_input = payload.get("tool_input") or {}
    SESSION["id"] = payload.get("session_id", "")
    if payload.get("tool_name") == "Bash":
        check_bash(tool_input.get("command") or "")
    elif payload.get("tool_name") == "Read":
        check_read(tool_input)
    sys.exit(0)


if __name__ == "__main__":
    main()
