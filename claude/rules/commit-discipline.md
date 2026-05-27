# Commit Discipline — Don't Commit Without Explicit Permission

## Core Rule

After completing code changes, **stop at "files modified."** Report what changed and wait for Tommy to authorize the commit. Do NOT `git add`, `git commit`, or `git push` unless he explicitly says so.

## Authorization phrases

Treat these as a green light to commit + push:
- "commit this" / "commit the changes" / "commit it"
- "push to staging" / "push it" / "send to staging"
- "let's ship it" / "ship this" / "ship"
- "deploy this" / "let's deploy"
- "go ahead and commit" / "okay, push it up"
- Any unambiguous "yes please commit" after you offered to.

If the wording is ambiguous ("looks good", "thanks") — **do not commit**. Ask: "Want me to commit + push to staging?"

## When NOT to commit (default state)

After ANY of these, default to NOT committing:
- Finishing a feature build, bug fix, or refactor
- Updating documentation or memory files
- Running tests successfully
- Hitting a green checkmark on type-checks or lints
- Replying to a clarifying question

If Tommy hasn't explicitly authorized a commit, the response should:
1. Summarize what changed (files, behavior, tests)
2. State that work is unstaged and waiting for his call
3. Stop

## What to do when authorized

When Tommy gives the green light:

1. **Stage only the relevant files explicitly** — never `git add -A` or `git add .` (the pre-staged-sweep rule still applies; check for Tommy's parallel WIP first via `git status` and `git diff --cached`).
2. **One commit, not many small ones**, unless the changes genuinely belong in separate commits (different repos, different feature areas).
3. **Commit message format** (see CLAUDE.md): short title line, blank line, bullet body explaining each change. End with the Claude co-author line.
4. **Push to staging only** — never to `main`. Production promotion is PR-only.
5. **Test reminder** — after pushing, create the macOS reminder per the existing rule.

## Why this rule exists

Every push to staging triggers:
- Cloud Build deploy (hub-backend / hub-frontend / docs frontend / web / help — depending on repo)
- E2E test suite (~5-10 min per repo)
- Cloud Run revision rollout

Five small auto-commits = five deploy cycles = five E2E runs = burning through GitHub Actions and Cloud Build minutes for what could have been one bundled story. Beyond cost: the staging commit history becomes a stream of micro-fixes that's hard to scan and harder to revert cleanly.

Tommy reset this on 2026-05-11 after a session that shipped several adjacent commits (Budget Health copy, then floor logic, then a follow-up) that would have read better as one bundled change with one deploy.

## Allowed bash operations even without commit authorization

The "don't commit" rule does NOT block:
- `git status` / `git diff` / `git log` (read-only inspection)
- Running tests
- Running the dev server / proxy / DB queries
- Editing files locally
- Type-checks, lints, builds

Only `git add` / `git commit` / `git push` require authorization.

## Edge cases

- **Multiple changes accumulated**: if Tommy gives a blanket "commit everything", look at all unstaged work, group into logical commits, and ask "Single commit or split by area?" before committing.
- **A push fails on hooks**: the commit didn't happen. Fix the issue and re-stage; do NOT `--amend`.
- **Tommy says "let me check first"** or pauses: continue waiting. Don't commit on a timer or by inference.
- **Mid-session, you've made many small edits**: that's fine — they're unstaged. The "bundle into one commit" approach handles them when authorized.

## Anti-patterns (never do)

- Auto-committing after a feature completes because "it's done now."
- Committing because tests pass.
- Pushing a doc-only change because "it's just docs."
- Committing memory file edits.
- Splitting a coherent change into 3 commits because the work happened in 3 file batches.
- Telling Tommy "I'm about to commit" without an answer — that's a heads-up, not an authorization.
