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

<!-- broad-glob-ok: cross-cutting by design — the pre-push gate applies to any pushable change -->

# Harden Before Push — Adversarial Challenge Gate

## Core Rule

Before any code that is **not purely cosmetic or copy-editing** is pushed to
a shared branch, an **independent agent** must challenge the completed work
— assume it is broken and hunt for footguns, bugs, silent failures, and
security holes — and the work must be **iteratively hardened** until an
adversarial round surfaces **no confirmed footgun/bug/security finding**.
Only then does the push happen.

The gate sits between *push authorized* and the actual push — not before the
local commit (see `commit-discipline.md`). Work is still committed locally
when done; the hardening loop runs when a push is authorized, and its fixes
become **follow-up commits** that ship with the push.

## What triggers the gate (and what's exempt)

**Triggers** — anything with a runtime or data surface:
- Logic, control flow, algorithms
- Backend routes, services, SQL, migrations, schema
- State, auth, permissions, multi-tenant scoping
- Money: pricing, billing, invoicing, payments, discounts
- External egress (email, payments, webhooks, third-party APIs)
- Data shape / API contract changes
- Anything that could 500, corrupt data, leak across tenants, or charge
  someone

**Exempt** — no hardening loop required:
- **Pure cosmetic**: styling, spacing, color, layout with **no logic
  change**
- **Pure copy**: user-facing text with **no behavior change**

**When in doubt, it triggers.** A "copy change" that also touches a
conditional, a "style fix" that reorders a hook, or a "tiny tweak" to a
query is not exempt. The exemption is for changes with *zero* runtime
surface, nothing else.

## The Gate — independent challenger + bounded loop

### Step 1 — Independent adversarial review (fresh agent, not the builder)
Launch a **separate agent** with adversarial framing: "This code is
complete and about to ship. Assume it's broken. Find the footguns —
unguarded edges, missing validation, silent failures, race conditions,
N+1s, unhandled errors, multi-tenant leaks, money/rounding errors, missing
migration/schema parity, enum/id gaps." Independence matters — the builder
is biased toward its own work; the challenger must run in a fresh context.

### Step 2 — Verify each finding before it drives a fix
Confirm findings from evidence — a speculative or hallucinated "bug" must
not cause churn (`diagnose-from-evidence.md` if your corpus ships it). A
finding that can't be confirmed is dropped or, if plausible-but-unproven,
logged (not fixed blind).

### Step 3 — Fix blocking findings; route the rest
Fix every **confirmed blocking** finding in scope, adding a regression
guard. Non-blocking findings (style, minor perf, nice-to-haves) are
**logged**, not fixed in the loop — and any bug that's out of scope or in
another session's WIP is routed per `found-bug-never-abandoned.md`, never
abandoned.

### Step 4 — Loop to convergence (BOUNDED)
Re-run Step 1 (a fresh adversarial pass fed the diff + the fixes just
made). Repeat until a round yields **zero confirmed blocking findings**.

- **Cosmetic/style/nice-to-have findings do NOT restart the loop** — only
  confirmed footgun/bug/security/correctness findings do. This is the
  halting criterion; without it the loop never terminates (an adversary can
  always nit).
- **Hard cap: 3 rounds.** If round 3 still surfaces confirmed blockers,
  **STOP — do not push.** That's the signal the work isn't ready. Surface
  the open blockers with repros; do not keep looping (looping past the cap
  is thrashing, not hardening).

### Step 5 — Harden
Beyond fixing what was found, apply the defensive hardening the review
implies: input validation at the boundary, transaction safety around
fallible writes, error logging with real messages, guard clauses for the
edges the challenger probed.

### Step 6 — Capture the class
Every **confirmed blocker** this gate produced — across all rounds,
including the ones already fixed — appends one line to your lessons ledger
if you keep one (`lessons-ledger.md`). Name the failure **class**, not the
instance. Nits are never logged; a clean round-1 PASS logs nothing.

## Severity gate — what blocks vs. what's logged

| Blocks the push (fix or explicitly accept) | Logged, does NOT block/loop |
|---|---|
| Correctness bugs, wrong output | Naming, formatting, style |
| Security / multi-tenant / auth holes | Minor/theoretical perf |
| Silent failures, swallowed errors | Nice-to-have refactors |
| Data-loss / money / rounding errors | Doc/comment polish |
| Footguns: unguarded edges, missing validation, races | Speculative "could someday" |
| Missing migration / schema parity | |

"Explicitly accept" means the person who owns the push signs off on a known
blocker shipping — not a silent pass.

## Calibrate the challenge to blast radius

- **Small logic change** (1–2 files, no money/auth/schema/egress): a
  **single** adversarial reviewer pass.
- **High blast radius** (money, auth, multi-tenant, schema/migration,
  external egress): a **full panel** of distinct adversarial lenses —
  correctness, silent-failure, security/multi-tenant, money/rounding,
  edge-cases — run in parallel, one agent per lens.

Don't run a max-effort audit on every push — match the rigor to the risk, or
the gate becomes friction that trains push-avoidance.

## Placement in the flow

```
build → verify → commit locally (commit-discipline)
      → [push authorized + non-cosmetic] → HARDEN-BEFORE-PUSH gate
      → fixes become follow-up commits → push
```

Report the gate's outcome alongside your normal verification report:
rounds run, confirmed findings fixed, and converged-vs-capped.

## Interaction with other rules

- **`commit-discipline.md`** — the gate is pre-**push**, post-**commit**.
  Fixes are follow-up commits (never amend a shared branch). Push still
  requires authorization; the gate runs after that authorization, before
  the push executes.
- **`found-bug-never-abandoned.md`** — Step 3 routes findings per that
  rule; the loop is where in-scope ones get fixed.
- **`no-glazing.md`** (overshoot guard) — the bounded halting criterion
  exists so the challenger doesn't manufacture criticism to keep looping.
  Cosmetic nits don't block.
- **`diagnose-from-evidence.md`** — Step 2 verifies findings before they
  drive fixes.

## Anti-patterns (never do)

- Pushing non-cosmetic code without the challenge gate.
- Letting the builder "review its own work" — the challenger must be a
  fresh, independent agent.
- Looping past the round cap chasing an adversary's nits — over-engineering,
  not hardening. Cap hit with real blockers → STOP and surface them.
- Treating a cosmetic/style finding as a blocker that restarts the loop.
- Fixing a finding you didn't confirm from evidence (churn from phantom
  bugs).
- Running a max-effort panel on a one-line style-adjacent tweak — friction
  that trains push-avoidance. Calibrate to blast radius.
- Classifying a change with a runtime surface as "cosmetic" to skip the
  gate.
- Silently shipping a known blocker — a blocker ships only on explicit
  accept.

## Why this rule exists

Deterministic pre-push checks (unit tests, mocked integration tests, type
checks) close the mock-vs-real gap, but they cannot catch an easy-to-misuse
API, an unguarded edge, or a silent-failure path that a skeptical reading of
the diff would spot. This gate adds that adversarial reading as a mandatory
pre-push step for anything with a runtime surface — bounded so it hardens
the code without thrashing, independent so the reviewer isn't the author,
and calibrated so the rigor matches the risk.
