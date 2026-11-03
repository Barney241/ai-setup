#!/usr/bin/env python3
import os
import sqlite3
import sys

STATE = os.path.expanduser("~/.t3/userdata/statev2.sqlite")


def main():
    thread = os.environ.get("T3CODE_THREAD_ID", "")
    if not thread or not os.path.exists(STATE):
        return
    try:
        connection = sqlite3.connect(f"file:{STATE}?mode=ro", uri=True, timeout=1)
        row = connection.execute(
            "select title from orchestration_v2_projection_threads where thread_id = ?", (thread,)
        ).fetchone()
    except sqlite3.Error:
        return
    if row and row[0]:
        print(row[0].replace("\n", " ")[:120])


if __name__ == "__main__":
    main()
    sys.exit(0)
