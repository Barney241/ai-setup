---
name: harness-guards
description: Use when a shell command is rejected by the sandbox, a worktree guard, a permission rule, or dcg, before running a long or background job, and when working across git worktrees.
---

# Harness guards

A rejection is expensive: the whole rejected command comes back into
context. Getting it right the first time is cheaper than a clever retry.

## Worktree guard

In a worktree session the harness must statically prove a command stays
inside the worktree. It rejects commands that mix paths with constructs it
cannot resolve: `$(…)`, indirect `$VAR` paths, `for`/`while` loops and
heredocs that touch paths. Chaining with `;` and `&&`, pipes, plain `$HOME`
and literal absolute paths for reads are fine.

- If a simple command is rejected, split it into plain separate calls.
- Anything with a loop, a heredoc, or more than two path-touching steps:
  write it to a script with the Write tool, then `bash <script>`. Do that
  first, not after a rejection.
- The guard cannot see inside the script, so its confinement becomes yours:
  every path the script writes stays inside the worktree or the session's
  scratch dir.
- Never use a script to get a rejected command past a guard. That is the
  one case where the rejection was telling you something true.
- Write and Edit are confined to the session's worktree. Switch worktrees
  with `EnterWorktree` instead of writing across.

## dcg (destructive-command guard)

dcg blocks by what a command would destroy, and sees only the outer command
string.

- `rm -rf`, `git restore`, `git checkout -- <path>`, `git reset --hard` are
  blocked. Reach the same state another way: re-run the generator, write
  into a fresh directory, or hand the user the exact command.
- A truncating redirect to a dynamic path (`> "$VAR/out"`) or anywhere under
  `$HOME` is blocked. Use the Write tool, a literal scratch path, or `>>`.
- Everything dcg forbids stays forbidden inside a script.

## Sandbox

- Never disable the sandbox preemptively. Most commands work sandboxed. Use
  the bypass only after a real sandbox error (`Operation not permitted`,
  `Read-only file system`, a `bwrap:` message, a blocked host), and name the
  error.
- TCP to localhost is blocked. A local database or dev server that "refuses
  connections" is usually up. Check `docker ps` before concluding it is down,
  then run the client with the bypass.
- Bash cannot write `.claude/` config, skills or `.mcp.json`. The Edit and
  Write tools can. To delete one, hand the user the exact `rm` line.
- A sandboxed command has its own PID namespace and cannot see processes
  started with the bypass. Watch the job's log file, not `pgrep`.
- Long jobs that need the bypass: see the machine quirks in the global rules
  (`setsid nohup … & disown` from a foreground call, then watch the log).

## Processes

`pgrep -f` and `pkill -f` match their own shell. Bracket one character:
`pgrep -f '[m]y-job'`. Never `pgrep -fa`: it prints full command lines,
exported secrets included.

## Scratch files

Use the Write tool or a per-session scratch path (`$TMPDIR/<task>/`). The
shared `/tmp/claude/` is used by every session: fixed names collide, and
`python /tmp/claude/x.py` imports any module another session left there.

## Git

- Never bare `git stash` / `git stash pop`. The stash stack is shared across
  every worktree. Prefer a WIP commit. If you must stash:
  `git stash push -u -m "<unique-tag>"`, capture the SHA from
  `git stash list --format='%H %gs'`, restore with `git stash apply <sha>`.
- Never `git branch -D` after a push. It orphans commits.
- After a PR squash-merges, branch follow-ups from the updated base.
- Before copying files across branches, check `git diff origin/<base>`.
- Push over HTTPS when SSH fails, without repointing `origin`.

## Worktrees

- A missing `config.worktree` makes bwrap fail. Fix it with `touch`, never
  `git worktree prune`.
- `direnv` does not reach non-interactive shells. The ai-setup plugin's
  session hook loads it and links `.env.local` from the main checkout.
- Lint and build caches can replay paths from sibling worktrees. Clear the
  tool's cache when findings point outside the current worktree.
- A wildcard in the directory part of a permission rule can walk
  `/nix/store` on every start. Anchor permission rules to literal prefixes.
