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
exports=$(direnv export zsh 2>/dev/null)
[ -n "$exports" ] && printf '%s\n' "$exports" > "$CLAUDE_ENV_FILE"
