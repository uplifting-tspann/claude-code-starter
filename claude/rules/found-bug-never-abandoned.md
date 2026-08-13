---
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*.jsx"
  - "**/*.py"
  - "**/backend/**"
  - "**/migrations/**"
  - "**/*.sql"
---

<!-- broad-glob-ok: cross-cutting by design — a bug can surface while touching any code -->

# Found Bug — Never Abandoned

## Core Rule

When you encounter a bug, error, or defect you did **not** set out to fix —
including one created by another agent or a parallel session, or a
"pre-existing" failure — you may **never** deprioritize it silently with
"these are pre-existing errors, not mine" and move on. **Finding a bug is a
first-class deliverable.** Every found bug is confirmed and **routed to a
resolution path**. It is never left in the code unacknowledged.

The agent that surfaces a latent bug in adjacent code did **more** than its
task, not less. Treat the finding as a win to be captured — not a distraction
to look away from.

## Why the "not mine" reflex exists (the tension this rule threads)

Commit-discipline (see `commit-discipline.md`) and general parallel-session
hygiene correctly ban **editing another session's uncommitted files** — a
parallel session's `checkout`/`reset` can silently destroy a completed,
staged fix, and blind-editing their files risks the same class of clobber.

But that ban trains a second, wrong behavior: **abandoning another session's
bugs.** The two must be separated:

- **Editing their files = still banned** (clobber risk).
- **Abandoning the bug = also banned** (this rule).

A found bug is *routed*, never dropped. You don't fix it by reaching into
their tree — you capture it with a precise repro and flag it so the owner
resolves it. The prohibition is on silent abandonment, not on respecting WIP
boundaries.

## The Protocol

### Step 1 — Confirm it's real

Don't log phantoms. Cite concrete evidence: the failing line, the error
output, a repro, the red CI step. A misread, an intended behavior, or your
own misunderstanding is **not** a bug — verify before you claim one. A real
error with evidence proceeds to Step 2. (See `diagnose-from-evidence.md` if
your rule corpus ships it — the same evidence bar applies here.)

A legitimate baseline observation ("this test also fails on a clean checkout
of main, so it's pre-existing") is **valid diagnosis** — but it does not end
your obligation. A confirmed pre-existing failure is exactly a found bug that
must be routed, not an excuse to stop.

### Step 2 — Route it (two paths, never a silent third)

**FIX NOW** — iff **all** of:
- it's in the same repo/area you're already working in, and
- the fix is small and self-contained, and
- you can actively verify it, and
- the buggy code is **not** another session's uncommitted WIP.

Then fix it and add a regression guard (test) so it can't come back.

**CAPTURE DURABLY** — otherwise (another session's live WIP, out of scope,
large blast radius, or unverifiable right now). This means **both**:
- **(a)** a concrete next-step item with **exact repro + proposed fix**, and
- **(b)** a durable record that survives the session — a tracked issue, a
  backlog entry in your project's roadmap/todo file, or (if your test suite
  supports it) a skipped test locked to the failure with a comment naming
  the intended behavior, flipped to enforced once the fix lands.

There is no third path. "Mention it in prose and move on" is the banned
behavior this rule exists to kill.

### Step 3 — Report it

Every coding turn that touched a bug ends with a short, explicit accounting:

```
Bugs Found:
- Fixed: <bug> — <how + the regression guard added>
- Logged: <bug> — <repro + where recorded>
- None
```

- Say `None` only when genuinely none were seen.
- Never omit this when a bug was encountered — a silent omission is
  indistinguishable from abandonment, which is the whole failure mode.
- One line per bug. A turn that fixes one and logs two gets three lines.

## Interaction with other rules

- **Commit discipline** — this rule does NOT license editing another
  session's files. When the bug is in their WIP, capture-durably and flag;
  never reach into their tree.
- **Evidence-first diagnosis** — confirm the bug from primary evidence before
  asserting it, so you route real defects, not guesses.

## Anti-patterns (never do)

- "These are pre-existing errors, not mine" followed by moving on. The exact
  behavior this rule bans.
- Editing another session's uncommitted files to fix their bug (clobber
  risk) — capture + flag instead.
- Logging a bug with no repro ("something's off in the invoice code") — a
  record without a repro can't be acted on and rots.
- Claiming a bug you didn't confirm from evidence — phantom findings waste
  the owner's time and erode trust in the report.
- Omitting the bug report when you saw a bug — silent omission is
  abandonment.
- Fixing an out-of-scope bug inline when it balloons the change or entangles
  two workstreams in one commit — capture-durably and let it ship on its
  own.
- Treating a confirmed pre-existing failure as "done" once diagnosed —
  diagnosis is Step 1, routing is still required.

## Why this rule exists

A recurring failure mode with concurrent agent sessions: an agent building
feature A hits a bug another agent left behind, says "pre-existing, not
mine," and walks past it — leaving a known defect in the code for someone to
rediscover later, usually a user. With several concurrent sessions on shared
branches, cross-agent bugs are common, and the parallel-session hygiene that
protects WIP had a side effect — it taught agents to look away from bugs
that weren't theirs.

The fix is not "fix every bug you find" (that would clobber live WIP). It's:
**a found bug is a deliverable that must be routed** — fixed when safe,
captured durably otherwise, never abandoned. Making the bug report mandatory
turns "look away and move on" into a visible, auditable choice that the rule
forbids.
