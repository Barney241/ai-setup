#!/usr/bin/env bash
set -u
[ -n "${CLAUDE_ENV_FILE:-}" ] || exit 0
command -v direnv >/dev/null || exit 0
cd "${CLAUDE_PROJECT_DIR:-$PWD}" || exit 0
main=$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')
if [ -n "$main" ] && [ "$main" != "$PWD" ]; then
  if [ ! -e .env.local ] && [ -f "$main/.env.local" ] && git check-ignore -q .env.local; then
    ln -s "$main/.env.local" .env.local
  fi
  cmp -s "$main/.envrc" .envrc && direnv allow .
fi

inlined_env_dir=$(dirname "$CLAUDE_ENV_FILE")
inlined_env_budget_kb=32
warn_when_inlined_env_is_large() {
  local total_kb
  total_kb=$(cat "$inlined_env_dir"/*.sh 2>/dev/null | wc -c | awk '{ print int($1 / 1024) }')
  [ "$total_kb" -gt "$inlined_env_budget_kb" ] || return 0
  echo "Session env files in $inlined_env_dir total ${total_kb}KB. Claude Code inlines them into every Bash call and the call fails with E2BIG near 128KB. A SessionStart hook is writing too much to CLAUDE_ENV_FILE, or appending on every start. Restarting or resuming adds more: fix the hook, then keep only the last line of the large file."
}

errors=$(mktemp)
exports=$(direnv export zsh 2>"$errors")
failure=$(grep -E 'error:|direnv: error' "$errors" | sed 's/\x1b\[[0-9;]*m//g' | head -n 3 | cut -c1-300 | tr '\n' ' ')
rm -f "$errors"
if [ -n "$failure" ]; then
  echo "direnv did not load the whole dev shell in $PWD, so its tools may be missing from Bash: $failure"
  echo "A sandboxed shell cannot build a cold flake cache. Run once with the sandbox disabled: direnv exec . true"
fi

if [ -n "$exports" ]; then
  exports_dir="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/ai-setup/session-env"
  exports_file="$exports_dir/$(basename "$inlined_env_dir").zsh"
  umask 077
  mkdir -p "$exports_dir"
  printf '%s\n' "$exports" > "$exports_file"
  printf 'if [ -r %q ]; then . %q; fi\n' "$exports_file" "$exports_file" > "$CLAUDE_ENV_FILE"
fi
warn_when_inlined_env_is_large
