---
name: fleet-analytics
description: Use when the user asks about agent usage across the fleet: tokens, cost, cache hit rate, tool or skill use, session history, what was prompted, failures, or "how much did I use". Also use when they say "fleet analytics" or "telemetry".
---

# Fleet analytics

Every host exports Claude Code and Codex telemetry to one ClickHouse, and T3
Code's traces and metrics to its raw `otel.*` tables. Answer from that data. Do not estimate from memory.

## How to query

Use the `ai-setup-telemetry` MCP tools. In a shell, or if they are missing:

```bash
ai-setup report                  # lists the reports
ai-setup report overview 7       # report name, days back
ai-setup query "SELECT ..."      # read-only SQL, returns TSV with a header
```

Start with a report, then drill down with SQL. If the sandbox blocks the
connection, use the MCP tools or the sandbox bypass.

## What to read

| Question | Use |
|---|---|
| Tokens, cost, cache by model | report `overview` |
| Trend over time | report `daily` |
| Which host or account | report `hosts` |
| Slow or failing tools | report `tools` |
| Skill use and outcomes | report `skills` |
| Most expensive sessions | report `sessions` |
| What went wrong | report `failures` |
| This period against the last | report `kpis` |
| Daily tokens and cost | report `trend` |
| Spending by project | report `projects` |
| Biggest tasks | report `tasks` |
| Biggest blockers | report `blockers` |
| Where the time goes | report `timings` |
| Slow tests, builds, commands | report `slow-commands` |

Custom SQL goes against these views. All carry `ts`, `host`, `agent`,
`session_id` and `account`, except `sessions`, which has one row per session.

| View | Row | Extra columns |
|---|---|---|
| `ai.requests` | one model request | `model`, `source`, `input_tokens`, `cached_tokens`, `cache_write_tokens`, `output_tokens`, `cost_usd`, `ttft_ms`, `duration_ms` |
| `ai.prompts` | one user prompt | `prompt`, `prompt_length` |
| `ai.responses` | one Claude response | `model`, `response` |
| `ai.tools` | one tool result | `tool`, `success`, `duration_ms`, `input`, `output` |
| `ai.skills` | one Claude skill activation | `skill`, `source`, `trigger` |
| `ai.api_errors` | one Claude API error | `model`, `detail` |
| `ai.sessions` | one session | `started`, `ended`, `prompts`, `tool_calls`, `tool_failures` |
| `ai.timings` | one wait | `phase`, `name`, `detail`, `duration_ms` |
| `ai.session_context` | one session | `project`, `branch` |
| `ai.tasks` | one session | `project`, `branch`, `task`, `total_tokens`, `api_usd`, `tool_minutes`, `prompts`, `tool_calls`, `tool_failures`, `started`, `ended` |
| `ai.events` | any agent event | `event`, `attrs` map |

Raw data is in `otel.otel_logs`, `otel.otel_traces` and `otel.otel_metrics_*`.

## Reading the numbers

- `input_tokens` excludes cached tokens for both agents, so ratios compare.
- `cost_usd` is Claude Code's API-equivalent estimate, not what a subscription
  costs. Codex reports no cost, so it stays null.
- Codex nests tools: an `exec` result can wrap an `exec_command` result, so one
  action can appear as two rows.
- Skills are recorded for Claude only. `ai.prompts` catches Codex skill
  triggers by their words.
- `phase` in `ai.timings` is `tool`, `model` or `permission_wait`. For the last,
  `name` is `source:decision`, and `config:` means no human was involved. Only
  Claude reports `model` and `permission_wait`; Codex has `tool` only.
- `project` comes from a session-start hook for Claude and from `workdir` in
  tool calls for Codex. A session that has neither is `unattributed`.
- A command started in the background returns at once, so its real run time is
  not in `duration_ms`. The later wait on it is a tool call of its own.
- `one_prompt_sessions` in the `skills` report is a proxy for needing no human
  help. It is not proof of a merged PR.
- Prompts and tool output are stored with common secret formats masked. The
  masking is best effort, so do not paste raw rows into PRs or public places.
