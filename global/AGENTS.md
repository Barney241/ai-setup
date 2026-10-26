# Loadout: fleet-wide agent rules

These rules travel with me to every host and every project. Project files
(`AGENTS.md`, `CLAUDE.md`, `.agents/loadout.md`) win wherever they are more
specific.

## No code comments

Code must read like a book. Never add comments to code. If code seems to need
a comment, it is not clean: rename, extract, or restructure until it doesn't.

Only when no refactor can make the code self-explanatory may you propose a
comment. Ask first, showing the exact comment and why refactoring can't
replace it. Add it only after confirmation.

## No memory

Auto-memory is off. Never write to or rely on memory files. Knowledge worth
keeping goes into a skill in loadout (if it holds in any repo), into the
project's `AGENTS.md` or `.agents/loadout.md` (if it is specific to one repo),
or into the papercuts log. Propose the exact edit instead of writing memory.

## Papercuts

Each project has a log at `~/Projects/papercuts/<repo>.md` of anything that
slowed development down. `<repo>` is the main checkout's directory name, the
parent of `git rev-parse --path-format=absolute --git-common-dir`, so all
worktrees of a repo share one file.

- When you lose time to tooling mid-session, append one line (create the file
  if missing): `YYYY-MM-DD · symptom · fix`.
- When tooling fails mysteriously, read this file first.

## Machine quirks

- `run_in_background: true` Bash calls stay sandboxed even with
  `dangerouslyDisableSandbox`. For a long job that needs the bypass, start it
  detached from a foreground call
  (`setsid nohup … > /tmp/claude/<job>.log 2>&1 < /dev/null & disown`) and
  watch the log.
- An exported `GH_TOKEN` may be a fine-grained PAT. Fine-grained PATs cannot be
  granted Checks access, so CheckRun and `statusCheckRollup.contexts` reads come
  back FORBIDDEN. Run those reads (including `pr-wait` and `gh pr checks`) with
  `env -u GH_TOKEN -u GITHUB_TOKEN` so gh uses the classic token in
  `hosts.yml`, or use the Actions runs/jobs API.
- `gh repo clone` can fail inside the sandbox on SSH config permissions. Clone
  over HTTPS instead.
- Nix commands need the daemon socket, which the sandbox blocks. Run them with
  the sandbox bypass.
- Playwright: `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH` points at a Nix-built
  Chromium that runs on NixOS. The `playwright` MCP server (loadout plugin)
  already uses it.

## Models and harnesses

Claude is the main driver. Other providers review, never drive.

| Seat | Provider (T3 `providerInstanceId`) | Model | Effort |
|---|---|---|---|
| Main driver | `claudeAgent` | latest Claude Opus | as set by the thread |
| Sol reviewer | `codex` | latest GPT Sol | `reasoningEffort: high` |
| Council | `claudeAgent`, `codex`, `antigravity` | latest Claude Opus, latest GPT Sol, latest Gemini Pro | high |

Resolve model IDs from `orchestrator_capabilities` every time. Never hardcode
them. If a seat's provider is unavailable or unauthenticated, report the seat
as missing. Never substitute another model.

## Asking the user

When you are working unattended (full send, full stop, babysitting), a
question in a normal message goes unseen. Use the harness question tool
(`AskUserQuestion` in Claude Code, `request_user_input` in Codex) with the PR
link, the blocker, and options with your recommendation first.

## Per-project configuration

Generic skills read repo-specific settings from `.agents/loadout.md` when it
exists: base branch, gate and check commands, review blockers, gating review
bots, draft policy, ticket pattern, release and deploy table. Fall back to
`AGENTS.md` / `CLAUDE.md`, then to what CI runs. A repo that ships its own
skill for the same job (its own release or PR-watch skill) wins over the
generic one.

## Improving the loadout

Skills are code. When an agent behaves badly, ask why, find the gap in the
skill, and patch the skill (`retro`). Edits go to the loadout checkout
(`loadout path`) and ship with `loadout push`, which syncs every host.
