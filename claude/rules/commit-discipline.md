# Commit Discipline — Auto-Stage, Never Auto-Commit

## Core Rule

After completing code changes, **automatically stage the modified files** (`git add <specific files>`) so they appear in your editor's staged area — then **stop**. Do NOT `git commit` or `git push` unless the user explicitly says so.

Staged = "done, ready to bundle or commit." Unstaged = "still cooking." This split is the user's visual dashboard in their editor's source-control panel for tracking what's ready across concurrent workstreams.

## Auto-Staging Rules

1. **Stage by explicit file path** — never `git add -A` or `git add .`
2. **Check for parallel WIP first** — run `git status` and `git diff --cached` before staging. If the user has files staged from another workstream, do NOT clobber them. Stage only THIS turn's files alongside whatever is already there.
3. **Report what was staged** — after staging, show `git diff --cached --stat` so the user can see the full staged picture.
4. **Only stage files this turn modified** — don't sweep in unrelated unstaged files from prior sessions or other workstreams.

## What NOT to Auto-Stage

- Memory files (assistant-internal notes, `.claude/` edits) — these are internal, not shipped
- Plan files — same reason
- Files the user explicitly asked to leave unstaged

## Commit Authorization Phrases

Treat these as a green light to commit + push:
- "commit this" / "commit the changes" / "commit it"
- "push to staging" / "push it" / "send to staging"
- "let's ship it" / "ship this" / "ship"
- "deploy this" / "let's deploy"
- "go ahead and commit" / "okay, push it up"
- Any unambiguous "yes please commit" after you offered to

If the wording is ambiguous ("looks good", "thanks") — **do not commit**. Ask: "Want me to commit + push, or keep it staged for bundling?"

## When NOT to Commit (Default State)

After ANY of these, default to staged-but-not-committed:
- Finishing a feature build, bug fix, or refactor
- Updating documentation or memory files
- Running tests successfully
- Hitting a green checkmark on type-checks or lints
- Replying to a clarifying question

If the user hasn't explicitly authorized a commit, the response should:
1. Summarize what changed (files, behavior, tests)
2. Stage the completed files
3. Report the staged diff
4. Offer commit + push vs. keep staged for bundling
5. Stop

## What to Do When Authorized to Commit

When the user gives the green light:

1. **Files are already staged** — verify the staged set is correct via `git diff --cached --stat`. If the user added or removed files from the staging area since auto-stage, respect their changes.
2. **One commit, not many small ones**, unless the changes genuinely belong in separate commits (different repos, different feature areas).
3. **Commit message format**: short title line (under 70 chars), blank line, bullet body explaining each change. End with a co-author trailer if your project uses one.
4. **Push to the integration branch** (often `staging` or `develop`) — not directly to `main` / `production`. Promotion to production should go through a PR.

## Why This Rule Exists

Every push to an integration branch typically triggers some combination of:
- CI builds (often several minutes per service)
- E2E test suites (often 5–10 minutes per repo)
- Deploy steps to a staging environment

Five small auto-commits = five build-and-deploy cycles = five test runs = burning through CI minutes for what could have been one bundled story. Beyond cost: the commit history becomes a stream of micro-fixes that's hard to scan and harder to revert cleanly.

A real example that motivated this rule: a session shipped three adjacent commits in quick succession (a UX copy tweak, then a logic fix, then a follow-up adjustment) that would have read better as one bundled change with one deploy.

Auto-staging solves the visibility problem without the cost problem: the user sees what's ready in the staged area and decides when to bundle and ship.

## Allowed Bash Operations (Always, No Authorization Needed)

- `git add <specific files>` (auto-stage after completing work)
- `git status` / `git diff` / `git diff --cached` / `git log` (read-only inspection)
- Running tests
- Running the dev server / proxy / DB queries
- Editing files locally
- Type-checks, lints, builds

Only `git commit` / `git push` require authorization.

## Edge Cases

- **Multiple changes accumulated**: if the user gives a blanket "commit everything", verify the staged set via `git diff --cached --stat`, group into logical commits if needed, and ask "Single commit or split by area?" before committing.
- **A push fails on hooks**: the commit didn't happen. Fix the issue and re-stage; do NOT `--amend`.
- **User says "let me check first"** or pauses: files stay staged. Continue waiting for commit authorization. Don't commit on a timer or by inference.
- **User unstages specific files**: respect that — they're curating what goes into the next commit. Don't re-stage files they removed.
- **Cross-workstream conflicts**: if `git diff --cached` shows files from a different workstream already staged, stage THIS turn's files alongside them. The user decides what gets committed together.

## Anti-Patterns (Never Do)

- Auto-committing after staging because "it's all staged now"
- Committing because tests pass
- Pushing a doc-only change because "it's just docs"
- Committing memory file edits
- Splitting a coherent change into 3 commits because the work happened in 3 file batches
- Using `git add -A` or `git add .` instead of explicit file paths
- Re-staging files the user explicitly unstaged
- Telling the user "I'm about to commit" without an answer — that's a heads-up, not an authorization
