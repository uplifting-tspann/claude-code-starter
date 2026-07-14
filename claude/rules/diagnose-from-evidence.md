# Diagnose From Evidence — Verify Before Asserting a Cause or an Urgent Action

## Core Rule

Before telling the user **what is wrong in production** or recommending an
**urgent or irreversible action** (grant/revoke a permission, restart a
service, roll back, rotate a secret, apply a prod migration, "the deploy is
blocked, do X now"), verify the claim against **primary evidence** — the
actual failing build step, the live permission policy, the real log line, the
real config value. Never infer a cause and escalate it as fact.

Inference is fine for *your own next step* (you'll find out immediately if
you're wrong). It is not fine for *a recommendation that costs the user an
action*, because a wrong one wastes their attention and trains them to
distrust your alarms.

## The bar scales with urgency and irreversibility

| What you're about to say | Evidence required first |
|---|---|
| "Here's a hypothesis, let me check" | none — but label it a hypothesis |
| "The build is failing because of step X" | read the build's **failing step** + its log |
| "You need to grant/rotate/restart Y — urgently" | read the **live state** of Y (the permission policy, the secret, the running revision) and confirm it's actually the cause |
| Anything irreversible (rollback, delete, prod migration) | reproduce the cause from evidence AND confirm the target state before acting |

The more urgent or irreversible the action you're recommending, the more
you must verify **before** the recommendation leaves your mouth — not
after.

## Build / deploy failures specifically

- **Pull the actual failing STEP, not the first plausible one.** A build
  fails at the *earliest* failing step; every later step is `QUEUED` and
  never ran. Blaming a step that was queued (never executed) is a classic
  wrong diagnosis. Ask your CI for the machine-readable step list, find
  the step whose status is `FAILURE`, then read *that* step's log.
- **Read the error, don't pattern-match the feature.** "I just shipped a
  new gate, so the gate must be what's failing" is a guess. In the
  incident below, the build was failing several steps earlier on a
  missing-column error — the gate step was `QUEUED` and had never run.

## Permission / config / secret claims

- Before "grant permission P to identity I", **read the live policy** —
  it may already be granted.
- Before "secret X is missing / wrong", read the live binding on the
  running service.
- Before "env var V isn't set", check the actual deployed service config.

These are read-only, 30-second checks. Do them **before** the sentence,
not after the user asks "are you sure?".

## Calibrate confidence in the words you use

- Verified from evidence → state it plainly.
- Not yet verified → "likely / probably / my guess is — let me confirm
  before you act." Do **not** dress an unverified inference as an urgent
  imperative.
- If you already said something with false confidence and then find it
  was wrong: **lead with the correction, plainly** ("Two things to
  correct, directly: …"), don't bury it or soften it. (This composes
  with `no-glazing.md`.)

## Why this rule exists

Mid-incident, Claude told the user that a newly-shipped schema-drift gate
was **blocking staging deploys** and that they needed to **grant the CI
service account a database-client role** — flagged as urgent. Both halves
were wrong: the service account **already had** that role, and the build
was failing at an *earlier* step (an integration-test step, on a missing
column), so the gate had **never run**. Two unverified assumptions were
escalated into an urgent production action.

The real cause — a test-fixture schema-parity miss, also Claude's — was
sitting in the failing step's log the whole time, and the permission state
was one read-only query away. Both checks were trivial and would have
prevented the wrong call. Diagnose from evidence, especially when it's
urgent.

## Anti-patterns (never do)

- Naming a build's failure cause without reading the failing step's log.
- Blaming the step you most recently touched instead of the step that
  actually failed.
- "You need to grant/restart/rotate X" without first reading X's live
  state to confirm it's the cause and not already correct.
- Presenting an inferred cause as an urgent imperative.
- Softening or burying a correction once you realize a confident claim
  was wrong.
