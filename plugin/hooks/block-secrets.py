#!/usr/bin/env python3
import glob
import json
import os
import re
import shlex
import sys

DUMPING_READERS = {
    "cat", "head", "tail", "less", "more", "bat", "view", "nl",
    "xxd", "od", "strings", "jq", "yq", "tac", "shuf", "base64",
}

SPLIT_OPERATORS = re.compile(r"\|\||&&|[;|&\n]")

SAFE_SUFFIXES = (".example", ".sample", ".template", ".dist", ".pub", ".age")

PRIVATE_KEY_NAMES = re.compile(r"id_(rsa|dsa|ecdsa|ed25519)(_sk)?")

PLAIN_SECRETS_FILE = re.compile(r"secrets(\.[\w-]+)?\.(ya?ml|json|env|toml)")


def sensitivity(path):
    base = os.path.basename(path)
    if base.endswith(SAFE_SUFFIXES):
        return None
    if base == ".env" or base.startswith(".env."):
        return ".env file"
    if PLAIN_SECRETS_FILE.fullmatch(base):
        return f"{base} (secret values)"
    if base.endswith(".tfvars"):
        return ".tfvars file (sensitive variable values)"
    if PRIVATE_KEY_NAMES.fullmatch(base) or base.endswith((".pem", ".key", ".p12", ".pfx")):
        return f"{base} (private key)"
    if base in {".netrc", ".pgpass", "seal"}:
        return f"{base} (credentials)"
    return None


def block(what, hint=""):
    print(f"BLOCKED: Cannot read/edit {what}.", file=sys.stderr)
    print("Inspect its shape with grep/cut/awk on key names instead of dumping values.", file=sys.stderr)
    if hint:
        print(hint, file=sys.stderr)
    sys.exit(2)


def check_file_tool(tool_input):
    path = tool_input.get("file_path") or tool_input.get("notebook_path")
    if path:
        reason = sensitivity(path)
        if reason:
            block(reason)


def tokens_of(segment):
    try:
        return shlex.split(segment)
    except ValueError:
        return segment.split()


def expand(token, cwd):
    if not any(c in token for c in "*?["):
        return [token]
    pattern = token if os.path.isabs(token) else os.path.join(cwd, token)
    return glob.glob(pattern)


def check_bash(command, cwd):
    for segment in SPLIT_OPERATORS.split(command):
        tokens = tokens_of(segment.strip())
        if not tokens or tokens[0].rsplit("/", 1)[-1] not in DUMPING_READERS:
            continue
        for token in tokens[1:]:
            if token.startswith("-"):
                continue
            for candidate in expand(token, cwd):
                reason = sensitivity(candidate)
                if reason and candidate != token:
                    block(reason, f"`{token}` expanded onto {os.path.basename(candidate)}. List the directory, then name the files you want.")
                if reason:
                    block(reason)


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        sys.exit(0)
    tool_input = payload.get("tool_input") or {}
    if payload.get("tool_name") == "Bash":
        check_bash(tool_input.get("command") or "", payload.get("cwd") or os.getcwd())
    else:
        check_file_tool(tool_input)
    sys.exit(0)


if __name__ == "__main__":
    main()
