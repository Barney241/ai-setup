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
errors=$(mktemp)
exports=$(direnv export zsh 2>"$errors")
if [ -z "$exports" ]; then
  echo "dev shell not loaded in $PWD: $(tail -n 3 "$errors" | tr '\n' ' ')" >&2
  echo "A sandboxed shell cannot build a cold flake cache. Run once with the sandbox disabled: direnv exec . true" >&2
  rm -f "$errors"
  exit 0
fi
rm -f "$errors"
printf '%s\n' "$exports" >> "$CLAUDE_ENV_FILE"
