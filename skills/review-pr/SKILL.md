---
name: review-pr
description: Use when the user says "review pr", "review these prs" or hands over one or more PR links to review with the council or Sol. Findings are shown first and posted only on the user's go, as inline comments on the affected code.
---

# review-pr

Review one or more PRs with the council (or Sol alone if the user says so),
show the merged findings, and post them only after the user says go. Each
finding becomes its own inline comment on the code it affects.

## 1. Pin each PR

For every PR: `gh pr view <n> --json number,title,headRefName,baseRefName,headRefOid,changedFiles,additions,deletions,state,isDraft`.
Pin `headRefOid`. Review that SHA, never the moving branch. Never check a PR
out in a shared checkout; reviewers read with `gh pr diff`,
`git fetch origin pull/<n>/head` and `git show <sha>:<path>`, and use their
own scratch worktree for anything that runs.

When PRs overlap (same feature, same files), say so in the brief and ask for
a cross-PR check.

## 2. Run the seats

Seats come from the model roster in the global rules. Resolve IDs with
`orchestrator_capabilities`; never hardcode them. Default is the `council`
skill: Claude Opus, GPT Sol, Gemini Pro, high effort. "Sol" alone means the
Sol seat only. One `delegate_task` per seat, `role: "review"`, async, each
covering all the PRs. A very large PR may get its own delegate per seat.

A seat that is unavailable or out of quota is reported as missing. Never
substitute a model.

Brief every delegate with: read-only (no edits, no PR comments, no
checkout of a PR branch), the pinned SHAs, how to read, the
`precision-review` contract with the repo's rules (AGENTS.md,
`.agents/ai-setup.md` review blockers, REVIEW.md files, the repo's no-comment
rule and the other conventions it enforces), the risk paths to push on, and
this output per PR: verdict, findings as
`R<n> [blocker|should|nit] [trivial|real|costly] <file>:<line> "<quoted code>" <what breaks>. Evidence. Fix.`,
a score out of 10, `Reviewed` / `Not reviewed`.

Wait for the completion notices. Do not poll.

## 3. Merge and show

Merge per `precision-review`: same defect from two seats keeps the highest
severity and names every seat. Delete a finding only with something that
disproves it. Re-fetch anything stateful a finding relies on (CI status,
PR head SHA) this turn before reporting it.

Show the user, per PR: verdict and scores per seat, then findings with
severity, seat names, `file:line`, and what is unverified. Name missing seats.
End by asking whether to post. **Do not post before the user says so.**

## 4. Post on go

Post one review per PR, not a pile of loose comments:
`POST /repos/{owner}/{repo}/pulls/{n}/reviews` with `event: COMMENT`,
`commit_id` set to the pinned head SHA, a short `body`, and a `comments`
array. Build the JSON in a file and send it with `gh api --input`.

**One finding, one inline comment.** Anchor it to the lines it affects:
`path`, `line` and `side: RIGHT`; add `start_line` for a range. Each comment
follows `leaving-pr-comments` (attribution callout first, conclusion first,
quoted evidence, fix) and carries the severity and the seat names.

**Anchor only inside the diff.** Check the line against the PR's changed hunks
(`gh api repos/{owner}/{repo}/pulls/{n}/files` patches). A finding whose lines
are not in the diff, or that is not about one place (red CI, missing test,
undisclosed behaviour, PR-body claim, cross-PR concern), goes in the review
`body` under "Outside the diff", one bullet each. Never anchor a comment to a
nearby line to make it fit.

The review `body` carries the verdict, the scores per seat and any missing
seat, kept short. If a PR is a draft or closed, say so and ask before posting.

Verify after posting: the response carries the review URL and every comment
id. Count comments posted against findings. Report the URLs.

## Do not

- Post before the user's go, or post a finding the user dropped.
- Resolve, dismiss, approve or request changes on the user's behalf; the
  event is always `COMMENT`.
- Repeat a finding already raised by a bot or reviewer on the PR; read the
  existing threads first and skip or reference them.
- Put reviewer scores in a PR description unless the user asks (`council`
  does that for PRs the user is shipping, not for PRs under review).
