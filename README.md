# ai-setup

The agent skills, hooks and tools I carry to every host and every project.
Claude Code is the main driver; Codex (GPT Sol) and Antigravity (Gemini)
review through [T3 Code](https://github.com/pingdotgg/t3code)'s
`delegate_task`. Built on [tstack](https://github.com/t3dotgg/tstack) (see
[NOTICE](NOTICE.md)).

Everything here is generic. Anything true of only one repo lives in that
repo's `.agents/ai-setup.md` ([template](templates/ai-setup.md)) or in a
project skill.

## Skills

Descriptions are triggers, not summaries. Say the words, chain them in one
sentence: "modernize #123, sol loop, full stop".

| Skill | Say | What it does |
|---|---|---|
| `full-send` | "full send" | Takes a change to a merged PR with nobody watching: proves it, reviews it, files it, babysits it, merges it. |
| `full-stop` | "full stop" | Same as `full-send`, but stops when the PR is ready for you to merge. |
| `sol-loop` | "sol loop" / "soul loop" | GPT Sol reviews the change in a loop until both agree. 3 rounds, 5 for security or data loss. |
| `council` | "council" | Claude Opus, GPT Sol and Gemini Pro review; loops until they agree; scores go in the PR. |
| `prove` | "prove it", "verify" | Evidence the change works: reproduce, fail-on-base, the running app, screenshots. |
| `precision-review` | "precision review" | The review contract every reviewer works to: evidence, severity and effort, scope. |
| `file-pr` | "file a PR" | Short PR that leads with the problem. Repo preflight from `.agents/ai-setup.md`. |
| `babysit-pr` | "babysit" | Watches a PR through CI and review bots and fixes the real findings. |
| `modernize` | "modernize" | Rebases an old PR and decides whether it should still exist. |
| `cut-release` | "cut a release" | Version, gates that mirror prod, tag, notes, deploy, health checks. |
| `retro` | "retro" | Why did the agent do that? A better next prompt, and a patch to the skill. |
| `fleet-analytics` | "fleet analytics", "how much did I use" | Answers usage questions from the fleet telemetry store. |
| `harness-guards` | (automatic) | What to do when the sandbox, a worktree guard or dcg rejects a command. |
| `agent-report` | (automatic) | Coverage block for investigation subagents. |
| `leaving-pr-comments` | (automatic) | Format for comments an agent posts on my behalf. |

Subagent: `ci-digest` (Haiku) reads one failed CI log and returns only the
failures.

Plugin `ai-setup` (Claude Code): a secret-file guard, per-project direnv
loading in worktrees, a headless Playwright MCP server with a Nix Chromium,
and the telemetry MCP server.

[`global/AGENTS.md`](global/AGENTS.md) holds the rules every agent on every
host follows, including the model roster. Claude imports it from
`~/.claude/CLAUDE.md`; Codex and Antigravity get it as `~/.codex/AGENTS.md`
and `~/.gemini/GEMINI.md`.

## How it reaches every host

```
edit skill ──► ai-setup push ──► GitHub ──► every host: ai-setup-sync.service
                    │                       (timer every 15 min, and at login)
                    └──ssh──► other hosts: systemctl --user start ai-setup-sync
```

Each host keeps a live checkout (`ai-setup path`). `ai-setup sync` clones it
if missing, fast-forwards it (never over local edits or a diverged branch),
and links each skill into `~/.claude/skills` and `~/.agents/skills`. Links it
did not create are never touched, so claude.ai synced skills and other tools'
skills live alongside. A new skill reaches every host without a rebuild.

| Command | Does |
|---|---|
| `ai-setup setup` | once per host: sync, then sign in to gh (plus git credentials), Claude, Codex and Antigravity if needed, check fleet SSH and T3's Antigravity provider, run `doctor` |
| `ai-setup sync` | clone, fast-forward, relink, refresh the plugin and the Codex MCP entry |
| `ai-setup push [msg]` | commit, rebase, push, sync every other host now |
| `ai-setup status` / `doctor` | checkout state and last sync / tools, auth, links, telemetry |
| `ai-setup report [name] [days]` | run a telemetry report, or list them |
| `ai-setup query <sql>` | read-only SQL against the telemetry store |

## Telemetry

Claude Code, Codex and T3 Code export OpenTelemetry to one ClickHouse, so usage
across every host can be queried in one place. No proxy sits in front of the
providers and sign-in does not change.

```
Claude Code ─┐
Codex ───────┼─ OTLP over the tailnet ─► otelcol-contrib ─► ClickHouse ─► ai.* views
T3 Code ─────┘                           redacts, drops noise             ├─ ai-setup report / query
                                                                          ├─ ai-setup-telemetry MCP
                                                                          ├─ fleet-analytics skill
                                                                          └─ web dashboard
```

The dashboard runs on the server at `http://<address>:8125`, for any device on
the tailnet: this period against the last, tokens per day, biggest blockers,
spending by project and the biggest tasks. It runs the same SQL as
`ai-setup report`, so the numbers match what agents see.

Claude Code telemetry has no project field. A session-start hook in the plugin
sends the repo and branch, reading the endpoint from `~/.claude/settings.json`
because Claude does not pass `OTEL_*` variables to hooks. Codex projects come
from `workdir` in its tool calls.

Server, in the NixOS config of one always-on host:

```nix
imports = [ inputs.ai-setup.nixosModules.telemetry ];
services.ai-setup-telemetry = {
  enable = true;
  address = "100.64.0.1";
  readers = [ "100.64.0.1" "100.64.0.2" ];
};
```

It binds only to loopback and `address`, so it does not rely on the firewall.
Anyone on the tailnet can send telemetry and open the dashboard, which shows
task titles; only `readers` can run SQL, as the read-only `agent` user. ClickHouse's own `default` user stays on loopback.

Clients, in home-manager:

```nix
programs.ai-setup.telemetry = {
  endpoint = "http://100.64.0.1:4318";
  queryUrl = "http://100.64.0.1:8123";
  content = true;
};
```

`ai-setup sync` writes the `env` keys into `~/.claude/settings.json` and a
marked `[otel]` block into `~/.codex/config.toml`, and removes both when
`endpoint` is null. It leaves a Codex `[otel]` table of your own alone. Point
T3 Code at the same endpoint with `T3CODE_OTLP_TRACES_URL` and
`T3CODE_OTLP_METRICS_URL` in the environment of its server. Its data stays in
the raw `otel.*` tables; the `ai.*` views cover Claude Code and Codex.

`content = true` also stores prompts, responses and tool input and output. The
collector masks common token formats before they are stored, but that is best
effort, so treat the database as sensitive.

Raw data stays in `otel.*`, as written by the collector. The `ai.*` views give
it typed columns and one shape across agents, and because they are views a
schema change applies to history too. See
[`telemetry/schema.sql`](telemetry/schema.sql) and
[`telemetry/reports`](telemetry/reports).

## Install

NixOS / home-manager (what I use):

```nix
inputs.ai-setup.url = "github:Barney241/ai-setup";

home-manager.users.me = {
  imports = [ inputs.ai-setup.homeManagerModules.default ];
  programs.ai-setup = {
    enable = true;
    fleet = [ "desktop" "laptop" "server" ];
  };
};
```

It installs `ai-setup`, `gh`, `git`, `jq`, `python3`, `ripgrep`, the
Playwright CLI and MCP, sets `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH`, and runs
the sync timer. Turn on lingering for headless hosts so the timer runs
without a login.

Anywhere else:

```bash
git clone https://github.com/Barney241/ai-setup ~/Projects/personal/ai-setup
~/Projects/personal/ai-setup/bin/ai-setup sync
```

## Requirements

- An authenticated `gh`.
- T3 Code with the Codex and Antigravity providers signed in, for `sol-loop`
  and `council`. Without T3, a harness that can run those models.
- `python3` for `pr-wait` and the secret guard.

## License

[MIT](LICENSE). tstack-derived skills: [MIT](LICENSES-tstack), see
[NOTICE](NOTICE.md).
