# Diagnose From Evidence — Verify Before Asserting a Cause or an Urgent Action

## Core Rule

Before telling the user **what is wrong in production** or recommending an
**urgent or irreversible action** (grant/revoke an IAM role, restart a
service, roll back, rotate a secret, apply a prod migration, "the deploy is
blocked, do X now"), verify the claim against **primary evidence** — the
actual failing build step, the live IAM policy, the real log line, the real
config value. Never infer a cause and escalate it as fact.

Inference is fine for *your own next step* (you'll find out immediately if
you're wrong). It is not fine for *a recommendation that costs the user an
action* — a wrong one wastes their attention and trains them to distrust
your alarms.

## The bar scales with urgency and irreversibility

| What you're about to say | Evidence required first |
|---|---|
| "Here's a hypothesis, let me check" | none — but label it a hypothesis |
| "The build is failing because of step X" | read the build's **failing step** + its log |
| "You need to grant/rotate/restart Y — urgently" | read the **live state** of Y and confirm it's actually the cause |
| Anything irreversible (rollback, delete, prod migration) | reproduce the cause from evidence AND confirm the target state before acting |

## Build / deploy failures specifically

- **Pull the actual failing STEP, not the first plausible one.** A build
  fails at the *earliest* failing step; every later step is `QUEUED` and
  never ran. Find the step with status `FAILURE`, read *that* step's log.
- **Read the error, don't pattern-match the feature** you most recently
  shipped to it.

## Permission / config / secret claims

- Before "grant role R to identity I": check the live IAM policy for that
  identity — **it may already be granted.**
- Before "secret X is missing / wrong": read the live binding (your
  runtime's service config).
- Before "env var V isn't set": check the actual deployed service config.

These are read-only, cheap checks. Do them **before** the sentence, not
after the user asks "are you sure?".

## Calibrate confidence in the words you use

- Verified from evidence → state it plainly.
- Not yet verified → "likely / probably / my guess is — let me confirm
  before you act." Do **not** dress an unverified inference as an urgent
  imperative.
- If a confident claim turns out wrong: **lead with the correction,
  plainly**, don't bury or soften it.

## Anti-patterns (never do)

- Naming a build's failure cause without reading the failing step's log
- Blaming the step you most recently touched instead of the step that
  actually failed
- "You need to grant/restart/rotate X" without first reading X's live state
  to confirm it's the cause
- Presenting an inferred cause as an urgent imperative
- Softening or burying a correction once you realize a confident claim was
  wrong
