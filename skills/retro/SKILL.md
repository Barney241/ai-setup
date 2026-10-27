---
name: retro
description: Use when the user says "retro", "retrospective", "lessons", "what did you learn", "how should I have asked", or "why did you do that", or after a task that finished only with notable friction.
---

# Retro

Skills are code. When an agent does the wrong thing, find out why, then patch
the instruction that let it happen. Two payoffs: a better next prompt for the
user, and durable fixes. Evidence-driven, terse, no praise, no recap of what
went fine. Skip it when the task landed first try.

## Phase 1: how to ask next time

1. Reconstruct the first prompt that would have got this result in one shot.
2. Show before and after.
3. For each addition, name the missing ingredient and why it helped: the goal
   behind the request, constraints only the user knew, the success
   criterion, the authoritative source, what was already tried.

If the session went sideways because of your error or a bad skill, say so.
"Your prompt was fine; the gap was on my side" is a valid Phase 1.

## Phase 2: why it happened, and the fix

For each friction point, cite the evidence: the wrong output, the dead end,
the correction the user made. Then ask yourself why you did it: which
instruction you followed, which one you missed, which one was absent.

| Category | Fix goes to |
|---|---|
| An ai-setup skill pointed you wrong or missed a case that holds in any repo | the ai-setup skill (`ai-setup path` for the checkout) |
| Something only true of this repo | `.agents/ai-setup.md`, the repo's `AGENTS.md`, or a project skill |
| A recurring task with no skill | a new skill: name and one-line trigger |
| A tooling dead end and the workaround that worked | the papercuts log |
| A wrong assumption | the doc where the next session will look, with the signal that would have corrected it |

Rules:

- **Evidence or it doesn't go on the list.**
- **Generalize the rule, keep the incident as evidence.** Strip the feature
  name from the fix unless the fact is genuinely specific to it.
- **Never put repo specifics in ai-setup.** ai-setup is public and generic.
  Service names, hosts, internal tools and credentials stay in the project.
- **Fix the root.** If a wrong fact lives in three places, fix all three.
- **Prune while you are there.** Skills grow bloated. Cut lines that no
  incident ever needed.
- **Write the exact edit.** The line before and after, the file path.
- **Confirm before applying**, except a trivially correct factual fix.
- No memory files. See the global rules.

## Shipping an ai-setup fix

Edit in the checkout, then `ai-setup push "<skill>: <what changed and why>"`.
It commits, pushes, and syncs every host.

## Output

```
## How to ask next time
Before: …
After:  …
Why:    <ingredient → payoff>

## Fixes
1. [ai-setup:<skill>] <finding + evidence> → <exact edit>
2. [project] <finding + evidence> → <file and edit>
3. [papercut] <line>
Apply these?
```
