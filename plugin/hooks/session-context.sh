#!/usr/bin/env bash
set -u
command -v jq >/dev/null && command -v curl >/dev/null || exit 0
endpoint="${OTEL_EXPORTER_OTLP_ENDPOINT:-$(jq -r '.["env"].OTEL_EXPORTER_OTLP_ENDPOINT // empty' "$HOME/.claude/settings.json" 2>/dev/null)}"
[ -n "$endpoint" ] || exit 0

input=$(cat)
session=$(jq -r '.session_id // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$session" ] && [ -n "$cwd" ] || exit 0

common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
case "$common" in
  */.git) project=$(basename "$(dirname "$common")") ;;
  *) project=$(basename "$cwd") ;;
esac
branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
t3_thread="${T3CODE_THREAD_ID:-}"
t3_title=$(python3 "$(dirname "$0")/t3-title.py" 2>/dev/null)

payload=$(jq -n \
  --arg session "$session" --arg project "$project" --arg branch "$branch" \
  --arg t3_thread "$t3_thread" --arg t3_title "$t3_title" \
  --arg host "$(uname -n)" --arg now "$(date +%s%N)" '
  def attribute($name; $value): { key: $name, value: { stringValue: $value } };
  {
    resourceLogs: [{
      resource: { attributes: [attribute("service.name"; "ai-setup"), attribute("host.name"; $host)] },
      scopeLogs: [{
        logRecords: [{
          timeUnixNano: $now,
          body: { stringValue: "session_context" },
          attributes: [
            attribute("session.id"; $session),
            attribute("project"; $project),
            attribute("branch"; $branch),
            attribute("t3_thread_id"; $t3_thread),
            attribute("t3_title"; $t3_title)
          ]
        }]
      }]
    }]
  }')

curl --silent --output /dev/null --max-time 2 \
  --header 'Content-Type: application/json' \
  --data-binary "$payload" "$endpoint/v1/logs"
exit 0
