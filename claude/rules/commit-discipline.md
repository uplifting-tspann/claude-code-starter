# Commit Discipline — Auto-Commit Locally, Never Auto-Push

## Core Rule

After completing code changes, **commit them locally by explicit path** —
then **stop**. Do NOT `git push` unless the user explicitly says so.

The durability boundary is the **commit**, not the index. Unstaged/staged
work can be silently destroyed by a parallel session; a local commit is safe
and costs nothing. Bundling multiple stories into one push happens at push
time, not by staging them together in the index.

| State | Durable against a parallel session? |
|---|---|
| Unstaged / staged | **NO — can be silently destroyed** |
| Committed locally | **YES** |
| Pushed | yes |

## Auto-Commit Rules

1. **Commit by explicit file path** — `git commit -F <msgfile> -- <path>
   <path>`. Never `git add -A`, `git commit -a`, or a bare `git commit`.
2. **Check for parallel WIP first** (`git status` / `git diff --cached`) —
   commit only your own paths; leave another session's staged/modified
   files untouched.
3. **Only commit work that is COMPLETE and VERIFIED** — a commit asserts
   your verification holds. Use the working tree, or a labeled `git stash
   push -m "<what>"`, for genuinely mid-flight work.
4. **Report the commit** — `git log --oneline -1` + `git show --stat HEAD`,
   plus anything left staged/modified by another session.
5. **Never amend, rebase, squash, or force-push** a shared branch. Wrong
   commit → add a follow-up commit, or `git revert` (or `git reset --soft
   HEAD~1` only if it's the tip, unpushed, and unpulled by anyone).
6. **Never push** without explicit authorization.

## What NOT to Commit

- Assistant-internal memory/config edits, plan files — internal, not shipped
- Files another session created or modified, or that the user asked to
  leave alone
- Work that is incomplete, unverified, or knowingly broken

## Push Authorization

Green light to push: "push to staging" / "push it" / "ship this/it" /
"deploy this" / "commit this/it" (often the user means ship — the work is
already committed locally) / any unambiguous yes after you offered to push.

Ambiguous wording ("looks good", "thanks") → do **not** push. Ask: push now,
or hold and bundle with the next story?

**Default after any completed work** (feature, fix, docs update, green
tests/lints, replying to a clarifying question): commit locally, then stop.
Summarize what changed → commit by explicit path → report `git log
--oneline -1` + `git show --stat HEAD` → offer push-now vs. hold-and-bundle →
stop.

## When Authorized to Push

1. `git log --oneline origin/<integration-branch>..HEAD` — report **every**
   commit going out, including other sessions' commits on the same branch
   (a push ships them too).
2. Bundle at push time — don't rebase/squash multiple local commits into
   one.
3. Push to your integration branch only — never straight to your
   production branch (prod promotion is PR-only).
4. Watch the build to completion. Report the actual result and, if red, the
   *failing step* — not a guess.
5. If you use a test-reminder convention, create it after a successful
   push.

## Allowed Without Authorization

`git add <files>` + `git commit -- <files>`; `git status`/`diff`/`diff
--cached`/`log` (read-only); `git stash push -m "<label>"`; running tests;
the dev server/proxy/DB queries; editing files locally; type-checks, lints,
builds.

**Only `git push` requires authorization.** Plus the always-forbidden set:
no `--amend`, no rebase, no force-push, no pushing to your production
branch.

## Edge Cases

- **Commit hook fails** → the commit didn't happen. Fix and re-commit; do
  NOT `--amend`.
- **User pauses to review** → the work is already committed and safe; don't
  push until they respond. If they want changes, add a follow-up commit.
- **Your staged/unstaged work vanished, no conflict** → a parallel session
  clobbered it. Rebuild and commit immediately rather than re-staging.
- **Another session's commits are on the branch at push time** → report
  every one; confirm none look half-finished.

## Anti-Patterns (Never Do)

- Leaving completed, verified work staged-but-uncommitted — not durable, a
  parallel session can destroy it silently
- Pushing without explicit authorization, including "it's just docs"
- Committing incomplete/unverified/broken work, or another session's/
  memory/plan files
- `git add -A` / `git add .` / `git commit -a` — sweeps in a parallel
  session's work
- `--amend`, rebase, squash, or force-push on a shared branch
- Splitting one coherent change into multiple commits because the work
  happened in multiple file batches
- "I'm about to push" without an actual answer — that's a heads-up, not
  authorization

## Why This Rule Exists

The staged-index model (commit only on explicit authorization, stay staged
otherwise) sounds safer than it is: `git status`/`diff --cached` show what's
staged, but staged work is not durable — a parallel session's `git
checkout`/`reset`/`restore` can wipe it with no warning, and this has
happened in practice. A local commit costs nothing and survives exactly the
same accident. Moving the durability boundary from "staged" to "committed
locally" closes that gap without changing anything about when a push
actually happens — push authorization is unchanged, only unauthorized.
