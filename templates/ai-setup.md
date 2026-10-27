# ai-setup settings for this repo

Copy to `.agents/ai-setup.md` and keep only the sections that differ from the
defaults. Generic ai-setup skills read this file. Anything that is true only of
this repo belongs here or in a project skill, never in ai-setup.

## Branches

- Base branch: `main`
- Merge method: squash
- Rebase or merge the base into PR branches: rebase

## Checks

Run every row whose path matches the change. Narrowest first while iterating,
the full row before calling the work done.

| Changed path | Must pass |
|---|---|
| `**` | `make lint test` |

## Live verification

How to run the app or stack, the test user, and what to drive by hand.

- Start: `…`
- Test user: `…` (local only)
- UI proof: which screens, locales, themes

## Pull requests

- Draft first: no
- Ticket pattern: `[A-Z]{2,}-\d+` in branch and title
- Title convention: conventional commits
- Pre-PR review command: none
- Gating review bots: greptile, macroscope
- Advisory review bots: coderabbit

## Review blockers

What blocks a merge in this repo, beyond the generic rules in
`precision-review`. Risk paths that always get the deepest review.

## Release

- Version source: git tag `vX.Y.Z`
- Gates that mirror the prod build: `…`
- Deploy target: Coolify / GitHub release / none

| App | Deploy id | Order | Health check |
|---|---|---|---|
| api | `…` | 1 | `curl -fsS https://…/healthz` |
