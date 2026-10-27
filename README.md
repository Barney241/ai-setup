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
sentence: "take over #123, sol loop, full stop".

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
| `takeover` | "take over" | Finishes someone else's PR, branch or agent thread and keeps their credit. |
| `modernize` | "modernize" | Rebases an old PR and decides whether it should still exist. |
| `cut-release` | "cut a release" | Version, gates that mirror prod, tag, notes, deploy, health checks. |
| `retro` | "retro" | Why did the agent do that? A better next prompt, and a patch to the skill. |
| `harness-guards` | (automatic) | What to do when the sandbox, a worktree guard or dcg rejects a command. |
| `agent-report` | (automatic) | Coverage block for investigation subagents. |
| `leaving-pr-comments` | (automatic) | Format for comments an agent posts on my behalf. |

Subagent: `ci-digest` (Haiku) reads one failed CI log and returns only the
failures.

Plugin `ai-setup` (Claude Code): a secret-file guard, per-project direnv
loading in worktrees, and a headless Playwright MCP server with a Nix
Chromium.

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
| `ai-setup status` / `doctor` | checkout state and last sync / tools, auth, links |

### Options I considered for fleet sync

| Option | Verdict |
|---|---|
| Live git checkout + user timer | **Used.** Editable in place, history, no rebuild per edit, offline hosts catch up. |
| SSH fan-out on push (over Tailscale) | **Used** on top, so a push lands everywhere in seconds. Unreachable hosts fall back to the timer. |
| Skills as a Nix flake input | Used only for the module and dependencies. For skill text it means a flake update plus a rebuild on every host for each edit, and read-only skills you can't patch mid-session. |
| Claude plugin marketplace auto-update | Used only for hooks and MCP. Plugin skills are Claude-only and namespaced; Codex and Antigravity would not see them. |
| Syncthing | No: no history or review, conflict files instead of merges. |
| GitHub webhook to a scheduler | No: needs a public endpoint. SSH fan-out does the same over the tailnet. |

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
