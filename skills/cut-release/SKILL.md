---
name: cut-release
description: Cut a release and deploy it. Use when the user asks to cut a release, ship a version, tag a release, or deploy to prod, and the repo has no release skill of its own.
---

# Cut release

A release is an annotated `vX.Y.Z` tag on the base branch, release notes,
and (when the repo deploys) a prod deploy of exactly that commit. Repo
specifics come from `.agents/ai-setup.md` `## Release`: version source, gates,
deploy table, health checks. A repo with its own release skill wins.

## 1. Preflight

- Clean tree, on the base branch, not ahead of or behind `origin`.
- `gh auth status` works.
- The commit to release is the base branch HEAD. Deploy targets that build
  the branch HEAD (Coolify, most PaaS) cannot deploy any other commit.

## 2. Version

- Last release: `git tag --sort=-creatordate | head -1`.
- Changes: `git log --merges --format=%s <last-tag>..origin/<base>`.
- Features: minor bump. Fixes only: patch. Breaking changes: major, and ask.
- State the version you picked in the report.

## 3. Gates that mirror the prod build

Run the gates the deploy will run, locally, before tagging. A red gate here
means prod fails the same way. Typical: the production build, the type check,
the test suite, `docker build` then run the image then `curl` its health
endpoint and assert a field. Long builds go detached with a log.

## 4. Notes

One sentence on what the release is about, then `## What changed` grouped by
theme with PR numbers. Base every claim on the PR description
(`gh pr view <n> --json body`), not on the title alone. Write the notes to a
file under `$TMPDIR`.

## 5. Tag and publish

Dry run first: print the tag, the commit, the notes path, and the commands.
Then apply:

```bash
git tag -a vX.Y.Z -m "vX.Y.Z" <commit>
git push origin vX.Y.Z
gh release create vX.Y.Z --notes-file <notes> --title "vX.Y.Z — <theme>"
```

Never move or delete a pushed tag without asking. A rerun for a version that
already exists stops and reports.

## 6. Deploy

Use the deploy table from `.agents/ai-setup.md`, in its order, waiting for
each app before the next.

- Set build-time variables (a version build arg, public analytics keys)
  before deploying. Changing a build argument afterwards needs a second
  deploy.
- List what will run against prod: the migrations between the last deployed
  commit and the release commit
  (`git diff --stat <deployed> <release> -- <migrations dir>`). Name any that
  drop or rewrite data in the report.
- Coolify specifics: `references/coolify.md`.

## 7. Confirm it landed

Run every health check in the table, then one real user action end to end
(`prove`). The new version must be visible where the app reports it.

## 8. Watch it settle

Many release problems show up only after a while: a slow memory leak, a
cron or queue job that runs later, cold caches, a migration that locks under
real traffic. Check again at these points after the deploy finishes:

| Checkpoint | When |
|---|---|
| 1 | right away (step 7) |
| 2 | after 10–15 min |
| 3 | after 30 min |
| 4 | after 1 h |

At each checkpoint:

- Every health check in the deploy table passes, and the reported version is
  still the release.
- No app restarted since the deploy: compare status, uptime or restart
  count with the previous checkpoint.
- Logs since the deploy: count errors and new error kinds, and compare with
  the same window before the deploy. Quote anything new.
- The post-deploy checks from `.agents/ai-setup.md` (`## Release`): error
  rate, latency, queue depth, whatever the repo lists.
- At checkpoints 2 and 4, repeat the real user action.

Wait between checkpoints with one background command that sleeps until the
next one is due and then exits (in Claude Code, `run_in_background`; it wakes
you when it ends). Never poll in a loop and never end your turn while
checkpoints remain, or nobody wakes you. Stay quiet at a clean checkpoint.

When a checkpoint fails, stop waiting and report at once: what broke, since
when, the evidence, and the rollback option (redeploy the previous release
commit). Ask before rolling back unless the user's request authorized it.
Under full send or full stop, ask with the harness question tool.

## Report

Version and why, tag and commit, release URL, each app deployed with its
result, migrations that ran, and one row per checkpoint:

| Checkpoint | Time | Health | Restarts | Errors vs before | Repo checks |
|---|---|---|---|---|---|
| 1 | 14:02 | pass | 0 | 0 new | pass |

Then anything not verified.

Production changes are outside full-send's grant. Under full send or full
stop, ask before deploying unless the user's request named the deploy.
