---
paths:
  - "**/backend/**"
  - "**/*.py"
---

> **Applicability:** This rule applies if you run **shared, always-running
> services** — a recurring scheduler, a cross-account sync job, a webhook
> handler that fires for every tenant, not just the feature being built —
> that get deployed alongside schema migrations. If your deploys never touch
> a service like that, delete this rule.

# Shared/Platform-Wide Jobs Referencing a New Migration Column — Deploy Order

## Core Rule

When a change touches a **shared, always-running service** — a recurring
scheduler, a cross-account sync job, a webhook handler that fires for every
tenant, not just the feature being built — and that change references a
column/table a migration in the SAME change just added, the migration MUST
be verified applied on the target environment BEFORE that code deploys
there. This is a live deploy-sequencing hazard, distinct from local
test/baseline drift: the shared job runs immediately on deploy, for every
tenant, and a missing column crashes it platform-wide, not just for the new
feature.

## Why this class of bug is easy to ship

A platform-wide job (a billing scheduler, a sync job — something that runs
unconditionally for every tenant) gets edited to reference a column that
only exists after a migration lands in the same change. The same column got
hard-coded a second time across a different code path in the same window.
Separately, a service invoked from multiple routes hard-depends on a column
existing with no compatibility guard — the migration has to land before
either deploy.

The common thread: each occurrence was a *different* shared job or service
hitting the same hazard by a different door, because nothing in the deploy
checklist forced the "is the migration actually applied yet?" question
before the code shipped.

## How to apply — checklist item before deploying migrations + code together

Before applying migrations and pushing code that touches a shared job:

1. **Identify whether the diff touches a shared/platform-wide service** —
   not feature-scoped code, but something that runs unconditionally for
   every tenant (schedulers, webhook handlers, cross-cutting sync jobs).
2. If yes, and the diff also references a column/table from a migration in
   the same change: **apply and verify that migration on the target
   environment FIRST** — migrations deploy ahead of code — and confirm via
   whatever schema-drift check you have before pushing the code.
3. Do not rely on "the migration is in the same commit" as sufficient — a
   rolling deploy means the OLD revision may still serve traffic against the
   NEW schema, or vice versa, for a window. A shared job with no defensive
   check (column-exists probe, try/except on the specific DB error) is the
   highest-risk case; prefer additive-safe code (e.g. `COALESCE` against a
   column that might not exist yet, or a version-gate) when the window can't
   be avoided.

## Anti-patterns (never do)

- Hard-coding a new migration's column into a scheduler/webhook/sync job
  without confirming the migration already applied on every environment
  that job runs against.
- Treating "the migration file exists in this change" as equivalent to "the
  migration is applied" — they are sequenced deploy steps, not one step.
