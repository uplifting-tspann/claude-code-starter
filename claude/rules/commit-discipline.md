# Commit Discipline — Don't Commit Without Explicit Permission

## Core Rule

After completing code changes, **stop at "files modified."** Report what changed and wait for the user to authorize the commit. Do NOT `git add`, `git commit`, or `git push` unless they explicitly say so.

## Authorization phrases

Treat these as a green light to commit + push:
- "commit this" / "commit the changes" / "commit it"
- "push to staging" / "push it" / "send to staging"
- "let's ship it" / "ship this" / "ship"
- "deploy this" / "let's deploy"
- "go ahead and commit" / "okay, push it up"
- Any unambiguous "yes please commit" after you offered to

If the wording is ambiguous ("looks good", "thanks") — **do not commit**. Ask: "Want me to commit + push?"

## When NOT to commit (default state)

After ANY of these, default to NOT committing:
- Finishing a feature build, bug fix, or refactor
- Updating documentation or memory files
- Running tests successfully
- Hitting a green checkmark on type-checks or lints
- Replying to a clarifying question

If the user hasn't explicitly authorized a commit, the response should:
1. Summarize what changed (files, behavior, tests)
2. State that work is unstaged and waiting for their call
3. Stop

## What to do when authorized

When the user gives the green light:

1. **Stage only the relevant files explicitly** — never `git add -A` or `git add .`. Check for parallel work-in-progress first via `git status` and `git diff --cached`. In multi-session repos, files may already be staged that aren't part of your change.
2. **One commit, not many small ones**, unless the changes genuinely belong in separate commits (different repos, different feature areas).
3. **Commit message format**: short title line (under 70 chars), blank line, bullet body explaining each change. End with a co-author trailer if your project uses one.
4. **Push to the integration branch** (often `staging` or `develop`) — not directly to `main` / `production`. Promotion to production should go through a PR.

## Why this rule exists

Every push to an integration branch typically triggers some combination of:
- CI builds (often several minutes per service)
- E2E test suites (often 5–10 minutes per repo)
- Deploy steps to a staging environment

Five small auto-commits = five build-and-deploy cycles = five test runs = burning through CI minutes for what could have been one bundled story. Beyond cost: the commit history becomes a stream of micro-fixes that's hard to scan and harder to revert cleanly.

A real example that motivated this rule: a session shipped three adjacent commits in quick succession (a UX copy tweak, then a logic fix, then a follow-up adjustment) that would have read better as one bundled change with one deploy. The user reset commit policy from auto-on-completion to wait-for-explicit-auth after that session.

## Allowed bash operations even without commit authorization

The "don't commit" rule does NOT block:
- `git status` / `git diff` / `git log` (read-only inspection)
- Running tests
- Running the dev server / proxy / DB queries
- Editing files locally
- Type-checks, lints, builds

Only `git add` / `git commit` / `git push` require authorization.

## Edge cases

- **Multiple changes accumulated**: if the user gives a blanket "commit everything", look at all unstaged work, group into logical commits, and ask "Single commit or split by area?" before committing.
- **A push fails on hooks**: the commit didn't happen. Fix the issue and re-stage; do NOT `--amend`.
- **User says "let me check first"** or pauses: continue waiting. Don't commit on a timer or by inference.
- **Mid-session, many small edits accumulate**: that's fine — they're unstaged. The "bundle into one commit" approach handles them when authorized.

## Anti-patterns (never do)

- Auto-committing after a feature completes because "it's done now"
- Committing because tests pass
- Pushing a doc-only change because "it's just docs"
- Committing memory file edits
- Splitting a coherent change into 3 commits because the work happened in 3 file batches
- Telling the user "I'm about to commit" without an answer — that's a heads-up, not an authorization
