---
name: proof
description: Structured verification protocol — exercise the change end-to-end, capture evidence, and emit the "Proof of Work" section the proof-of-work rule + Stop hook require. Use at the end of any coding task that modified files.
---

# Proof Protocol

You just completed work that modified files. Before ending the turn,
prove it works. Don't trust "the code compiles" or "type checks pass" —
exercise the actual user-facing path.

This skill pairs with the `proof-of-work` rule and the
`proof-stop-hook.sh` hook. The rule mandates the output format; the
hook blocks turn-end if the format is missing. This skill runs the
verification.

## Step 0 — Read config (optional but recommended)

Read `~/.claude/projects-config.json` if it exists. You'll use the
per-project `dev_command`, `dev_url`, and `tests` fields to drive
verification without asking.

If the config is missing or the current project isn't listed, fall back
to asking the user the minimal questions ("How do I run your dev
server?"). Don't refuse to run — graceful degradation.

## Step 1 — Identify the change

Run `git diff --stat` (or `git status` if nothing's committed yet) to
see what changed. Categorize:

- **UI feature/fix** (`.tsx`, `.jsx`, `.vue`, `.svelte`, frontend CSS) → Step 2A
- **Backend route/service** (backend `.py`, `.ts`, `.go`, etc.) → Step 2B
- **Refactor** (no behavioral change intended) → Step 2C
- **Bug fix** → Step 2D
- **Schema change** (migration `.sql`) → Step 2E
- **Trivial** (typo, comment, dead code, memory/plan file edit) → Step 3
  with short form

If the change spans multiple categories, do the verification for each.

## Step 2A — UI verification

Find the project this change belongs to. If projects-config has a
match, use its `frontend.dev_command` and `frontend.dev_url`.
Otherwise ask.

1. Start the dev server in the background if not running already.
   Check first — don't start a duplicate if one's already up on that port.
2. Drive the changed path. Either:
   - Open the URL in a browser (or take a screenshot) and visually
     verify.
   - If Playwright (or another browser-automation tool) is wired up,
     write a quick scratch test that exercises the path.
3. Verify outcomes:
   - The DOM has the expected element/text/state.
   - The browser console has no new errors.
   - The network panel has no new 4xx/5xx responses.

## Step 2B — Backend verification

Find the project this change belongs to. If projects-config has a
match, use its `backend.dev_command` and `backend.dev_url`.

1. Start the backend in the background if not running.
2. Hit the endpoint with `curl` using realistic input:
   ```bash
   curl -i -X POST <url>/api/<endpoint> \
     -H 'Content-Type: application/json' \
     -d '{"key": "value"}'
   ```
3. Verify:
   - Status code matches expectation (200, 201, 4xx as designed)
   - Response shape matches expectation
   - DB row was created/updated/deleted as designed (query and confirm)
4. Test at least one error case (invalid input, missing field) and
   confirm it returns a clean 4xx, not a 500.

## Step 2C — Refactor verification

Refactors should have NO behavior change. The proof is "the smoke
suite still passes."

1. Run the smoke test suite for the affected project (via the
   `test-runner` skill, or directly from projects-config's
   `tests.smoke` command).
2. Report pass/fail count.
3. If any tests fail that didn't before, treat this as a non-trivial
   behavior change and re-categorize to 2A/2B.

## Step 2D — Bug fix verification

Bug fixes need a REGRESSION TEST in addition to the verification:

1. **Reproduce the original bug first.** Run the broken flow against
   the un-fixed code (revert in your head if needed). Confirm you can
   see the bug.
2. Apply the fix.
3. **Re-run the same flow.** Confirm the bug is gone.
4. **Write a regression test** that exercises the exact path. Run it
   to confirm it passes now (and would have failed before).
5. The proof section should mention: "Added regression test
   `<test name>` covering this path."

## Step 2E — Schema change verification

1. Apply the migration on a non-production DB (staging, local, or a
   dedicated migration-testing instance).
2. Run `\d <table>` (or equivalent) to verify the new structure.
3. Exercise at least one downstream route/query that touches the
   changed table — confirm it still works.
4. If you have a "real-DB integration test" layer, run it.

## Step 3 — Emit the Proof of Work section

Output to the user, exactly this format (no creative variations — the
Stop hook checks for the literal "Proof of Work:" string):

```
Proof of Work:
- What changed: <one-line summary>
- How I verified: <specific steps — pages visited, curls run, tests run, screenshots>
- What I observed: <observed outcomes — DB row id, response shape, test pass>
- Not verified: <gaps and why — or "none">
```

For trivial changes:

```
Proof of Work: trivial — <reason>
```

The **"Not verified:" line is the most important one.** It surfaces
gaps the user would otherwise discover by stumbling. Be honest:
"didn't test on mobile," "didn't verify the rollback path," "skipped
the loaded-state edge case." Silent gaps are the actual failure mode
this protocol prevents.

## Anti-patterns (never do)

- "Type checks pass" or "It compiles" as the only proof — never enough.
- "The unit tests pass" — only counts if a unit test exercises this
  exact path. If not, write one or do live verification.
- Omitting the "Not verified:" line because everything seemed fine —
  list gaps explicitly even when small.
- Reporting "verified" without actually running the path. The hook
  catches missing sections; it can't catch fabricated ones, so don't.
