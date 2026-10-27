---
name: prove
description: Prove a change works with evidence observed in this session. Use when the user says "prove it", "verify", or "show me it works", before reporting a change done, and as the Proof step of full-send and full-stop.
---

# Prove

Proof is evidence you observed yourself in this session: command output, a
reproduction, a screenshot, a recording. A green task colour, a mocked test,
or "the tests cover it" is not proof.

## 1. What changed

`git diff --name-only $(git merge-base HEAD origin/<base>)` plus
`git status --short`. The base comes from `.agents/ai-setup.md`, else the repo
default branch.

## 2. Which checks

Take the check table from `.agents/ai-setup.md` (`## Checks`). Without one, use
the repo's `AGENTS.md` / `CLAUDE.md`, then whatever CI runs
(`.github/workflows/*`, `Makefile`, `justfile`, `package.json` scripts). Run
every row whose path matches. Run the narrowest check while iterating and the
full row before calling the work done.

## 3. Proof rules

- **Reproduce first.** Reproduce the original failure, apply the fix, then
  watch the same reproduction pass.
- **A green task is not proof tests ran.** Read the counts: test result files,
  the `ok`/`PASS` lines, the number of tests executed. Zero tests is a failure.
- **A new test must fail without the fix.** Prove it on the base: check the
  base out into a disposable worktree
  (`git worktree add <scratch> <merge-base>`), copy the new test in, watch it
  fail. Remove the worktree after.
- **Never weaken an expectation to make a test pass.** If the app is wrong,
  fix the app.
- **Drive it live when it can be driven.** Real request, real rows, real logs,
  using the lightest way the repo has to run it. A change that cannot be
  driven live needs the reason written in the PR description.
- **A visible change is not done until you have looked at it** in the running
  app.

## 4. Looking at the UI

Pick the first that is available:

1. **T3 Code preview tools.** `preview_open` on the dev server URL, then
   `preview_navigate`, `preview_click`, `preview_type`, `preview_snapshot`.
   Use `preview_recording_start` / `preview_recording_stop` for flows.
   `device_screenshot` for simulators and devices.
2. **Playwright MCP** (`playwright` server, from the ai-setup plugin). Headless,
   isolated profile, Nix Chromium. Navigate, act, screenshot.
3. **The repo's Playwright runner.** Write a throwaway spec and run it with
   the project's runner (`pnpm exec playwright test <spec>`). On NixOS, point
   the config at the Nix browser when the npm version doesn't match:

   ```ts
   use: { launchOptions: { executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH } }
   ```

   Prefer the test runner over a standalone node script.

Check every variant the change touches: locales, themes, viewport sizes,
logged in and out. Save screenshots under `$TMPDIR` and show them to the user
by absolute path. Attach them to the PR when the harness can upload.

## 5. Running the stack

- Check for a running dev server before starting one. Never start a second
  server on the same build directory or run a production build against a live
  dev server.
- The sandbox blocks TCP to localhost. Run curl, Playwright and seed scripts
  against local services with the sandbox bypass, and say that the bypass was
  for localhost.
- Long builds and e2e suites go detached with a log (see machine quirks). Cap
  heavy suites with `nice` when the repo documents it.
- Tear down what you started before handing off.

## 6. Acceptance contract for multi-step work

For a task with more than one behaviour, write a short contract under
`$TMPDIR/proof.md` before you finish: one copy-paste runnable check per
behaviour with its exact expected output, plus the negative cases. Run every
check and stamp it `Last run: <time> pass`. Never commit this file.

## Report

| Check | Command | Result |
|---|---|---|
| unit | `…` | pass, 142 tests |
| ui | Playwright MCP, `/settings`, dark + light | pass, screenshots: `…` |
| e2e | `…` | not run: needs prod credentials |

Paste failing output for any failure. Do not call the work done while a
matching row failed, or was skipped without a reason.
