#!/usr/bin/env python3
from datetime import datetime, timezone
import json
import os
import re
import signal
import socket
import sqlite3
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

CLAUDE_SETTINGS = Path.home() / ".claude" / "settings.json"
T3_STATE = Path.home() / ".t3" / "userdata" / "statev2.sqlite"
CURSOR_DIR = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local" / "state"))) / "ai-setup" / "antigravity-cursors"
DEADLINE_SECONDS = 3
MAX_TEXT_CHARS = 1500
MAX_INPUT_CHARS = 1000


def endpoint():
    for var in ("OTEL_EXPORTER_OTLP_ENDPOINT", "AI_SETUP_TELEMETRY_ENDPOINT"):
        configured = os.environ.get(var)
        if configured:
            return configured.rstrip("/")
    try:
        return json.loads(CLAUDE_SETTINGS.read_text()).get("env", {}).get("OTEL_EXPORTER_OTLP_ENDPOINT", "").rstrip("/")
    except (OSError, ValueError):
        return ""


def attribute(name, value):
    return {"key": name, "value": {"stringValue": str(value)}}


def parse_timestamp_ns(value):
    if not value:
        return str(time.time_ns())
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return str(int(dt.timestamp() * 1_000_000_000))
    except ValueError:
        return str(time.time_ns())


def log_record(body, attributes, time_ns=None):
    return {
        "timeUnixNano": time_ns or str(time.time_ns()),
        "body": {"stringValue": body},
        "attributes": [attribute(name, value) for name, value in attributes.items() if value != ""],
    }


def send_batch(target, service_records):
    resource_logs = []
    host = socket.gethostname()
    for service, records in service_records.items():
        if not records:
            continue
        resource_logs.append({
            "resource": {"attributes": [attribute("service.name", service), attribute("host.name", host)]},
            "scopeLogs": [{"logRecords": records}],
        })
    if not resource_logs:
        return
    request = urllib.request.Request(
        f"{target}/v1/logs",
        data=json.dumps({"resourceLogs": resource_logs}).encode(),
        headers={"Content-Type": "application/json"},
    )
    urllib.request.urlopen(request, timeout=2).read()


def git_info(cwd):
    if not cwd or not os.path.isdir(cwd):
        return "", ""
    try:
        common = subprocess.check_output(
            ["git", "-C", cwd, "rev-parse", "--path-format=absolute", "--git-common-dir"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1,
        ).strip()
        project = Path(common).parent.name if common.endswith("/.git") else Path(cwd).name
    except (OSError, subprocess.SubprocessError):
        project = Path(cwd).name
    try:
        branch = subprocess.check_output(
            ["git", "-C", cwd, "branch", "--show-current"],
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=1,
        ).strip()
    except (OSError, subprocess.SubprocessError):
        branch = ""
    return project, branch


def t3_title(thread_id):
    if not thread_id or not T3_STATE.exists():
        return ""
    try:
        connection = sqlite3.connect(f"file:{T3_STATE}?mode=ro", uri=True, timeout=1)
        row = connection.execute(
            "select title from orchestration_v2_projection_threads where thread_id = ?", (thread_id,)
        ).fetchone()
        return row[0].replace("\n", " ")[:120] if row and row[0] else ""
    except sqlite3.Error:
        return ""


def clean_prompt(text):
    if not text:
        return ""
    stripped = re.sub(r"<t3_code_instructions>.*?(?:</t3_code_instructions>|$)", "", text, flags=re.S)
    match = re.search(r"<user_request>(.*?)(?:</user_request>|$)", stripped, flags=re.S)
    if match:
        stripped = match.group(1)
    else:
        stripped = re.sub(r"</?USER_REQUEST>", "", stripped)
    return re.sub(r"\s+", " ", stripped).strip()


def load_cursor(conversation_id):
    path = CURSOR_DIR / f"{conversation_id}.json"
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return {"step": -1, "context_sent": False}


def save_cursor(conversation_id, state):
    try:
        CURSOR_DIR.mkdir(parents=True, exist_ok=True)
        (CURSOR_DIR / f"{conversation_id}.json").write_text(json.dumps(state))
    except OSError:
        pass


def context_record(conversation_id, cwd):
    project, branch = git_info(cwd)
    thread_id = os.environ.get("T3CODE_THREAD_ID", "")
    return log_record("session_context", {
        "session.id": conversation_id,
        "project": project,
        "branch": branch,
        "t3_thread_id": thread_id,
        "t3_title": t3_title(thread_id),
    })


def transcript_records(conversation_id, transcript_path, fallback_model, last_step):
    records = []
    max_step = last_step
    if not transcript_path or not os.path.isfile(transcript_path):
        return records, max_step
    try:
        with open(transcript_path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    step = json.loads(line)
                except ValueError:
                    continue
                idx = step.get("step_index")
                if not isinstance(idx, int) or idx <= last_step:
                    continue
                if idx > max_step:
                    max_step = idx
                step_type = step.get("type", "")
                ts_ns = parse_timestamp_ns(step.get("created_at", ""))
                if step_type == "USER_INPUT":
                    prompt = clean_prompt(str(step.get("content", "")))
                    records.append(log_record("antigravity.user_prompt", {
                        "session.id": conversation_id,
                        "prompt": prompt[:MAX_TEXT_CHARS],
                        "prompt_length": str(len(prompt)),
                    }, ts_ns))
                elif step_type == "PLANNER_RESPONSE":
                    model = str(step.get("model") or fallback_model or "")
                    records.append(log_record("antigravity.api_request", {
                        "session.id": conversation_id,
                        "model": model,
                        "query_source": "antigravity",
                        "input_tokens": str(step.get("input_tokens") or 0),
                        "cache_read_tokens": str(step.get("cache_read_tokens") or 0),
                        "cache_creation_tokens": "0",
                        "output_tokens": str(step.get("output_tokens") or 0),
                        "ttft_ms": "0",
                        "duration_ms": "0",
                    }, ts_ns))
                    content = str(step.get("content", "")).strip()
                    if content:
                        records.append(log_record("antigravity.assistant_response", {
                            "session.id": conversation_id,
                            "model": model,
                            "response": content[:MAX_TEXT_CHARS],
                        }, ts_ns))
    except OSError:
        pass
    return records, max_step


def handle_hook(payload):
    target = endpoint()
    if not target:
        return
    conversation_id = str(payload.get("conversationId") or "")
    if not conversation_id:
        return
    event = str(payload.get("hookEventName") or "")
    workspace_paths = payload.get("workspacePaths") or []
    cwd = str(payload.get("cwd") or (workspace_paths[0] if workspace_paths else ""))
    cursor = load_cursor(conversation_id)
    records = {"ai-setup": [], "antigravity": []}

    if event == "SessionStart" or not cursor.get("context_sent"):
        records["ai-setup"].append(context_record(conversation_id, cwd))
        cursor["context_sent"] = True

    if event == "PostToolUse":
        tool_call = payload.get("toolCall") or {}
        tool_name = str(tool_call.get("name") or "")
        tool_id = str(tool_call.get("id") or "")
        tool_args = tool_call.get("args") or {}
        error = str(payload.get("error") or "")
        records["antigravity"].append(log_record("antigravity.tool_result", {
            "session.id": conversation_id,
            "tool_name": tool_name,
            "tool_use_id": tool_id,
            "success": "false" if error else "true",
            "duration_ms": "0",
            "tool_input": json.dumps(tool_args, separators=(",", ":"))[:MAX_INPUT_CHARS],
            "error": error[:MAX_TEXT_CHARS],
        }))

    if event in ("PostInvocation", "Stop"):
        new_records, max_step = transcript_records(
            conversation_id,
            str(payload.get("transcriptPath") or ""),
            str(payload.get("modelName") or ""),
            int(cursor.get("step", -1)),
        )
        records["antigravity"].extend(new_records)
        cursor["step"] = max_step

    if event == "Stop" and (payload.get("terminationReason") == "ERROR" or payload.get("error")):
        records["antigravity"].append(log_record("antigravity.api_error", {
            "session.id": conversation_id,
            "model": str(payload.get("modelName") or ""),
            "error": str(payload.get("error") or payload.get("terminationReason") or "")[:MAX_TEXT_CHARS],
        }))

    send_batch(target, records)
    save_cursor(conversation_id, cursor)


def give_up(signum, frame):
    raise TimeoutError


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--backfill":
        transcript_path = Path(sys.argv[2])
        conversation_id = transcript_path.parents[2].name
        handle_hook({
            "hookEventName": "Stop",
            "conversationId": conversation_id,
            "transcriptPath": str(transcript_path),
            "cwd": os.getcwd(),
        })
        return
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        print("{}")
        return
    signal.signal(signal.SIGALRM, give_up)
    signal.alarm(DEADLINE_SECONDS)
    try:
        handle_hook(payload)
    except Exception:
        pass
    finally:
        signal.alarm(0)
    print("{}")


if __name__ == "__main__":
    main()
    sys.exit(0)
