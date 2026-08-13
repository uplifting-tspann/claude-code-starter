---
paths:
  - "**/backend/**"
  - "**/*.py"
---

# New Write Paths — Reuse the Guarded Service, Satisfy Every Downstream Reader

## Core Rule

Before writing a new INSERT/UPDATE/DELETE against a table that already has a
service function owning it (an `account_service`, a `delete_user`, a
`sync_access_for_contact` — whatever your codebase's canonical owner of that
table's writes is called), **call that function** — never hand-roll the SQL
again, even for a one-off script, a bulk route, or a webhook-driven write.
And before shipping any new path that CREATES a row in a table an existing
consumer already reads (a scheduler, a matcher, a due-date query), **check
what fields that consumer requires** — a new INSERT path is incomplete until
it satisfies every existing reader's assumptions, not just the new feature's
own read path.

## Why: two failure classes, same root cause

**Bypassed guard**: a new write path re-implements a table's write logic
instead of calling the service that already guards it, and silently drops
whatever invariant that service enforced — a duplicate-charge check, an
access-revoke sweep, a soft-delete cascade. Each occurrence is a DIFFERENT
new write path (a bulk-reassign route, a standalone migration script, a
webhook handler, a generic `allowed_fields` whitelist) reaching the same
already-guarded table by a different door.

**Missing downstream field**: a new row-creation path populates only the
fields its OWN feature needs, omitting a field a DIFFERENT already-existing
consumer requires (a due-date field a billing scheduler's query depends on,
a foreign key an access-revoke matcher joins on). The row looks correctly
created and passes every test scoped to the new feature — it silently fails
the first time the existing consumer tries to read it (never billed,
permanently unrevocable, whatever the specific consumer needed).

## How to apply

Before adding a new write path to any table:

1. **Grep for an existing service/function that already writes this table.**
   If one exists, call it — do not duplicate its guard logic, even
   partially. If you must write raw SQL (a one-off backfill, a script), read
   the service's full write path first and replicate EVERY guard it
   applies, not just the columns.
2. **Grep for every existing reader of this table** (schedulers, matchers,
   dashboards, other services) and confirm your new row satisfies what each
   one assumes — not just what your own feature's read path needs. A
   `SELECT` in a cron job or a matcher function is a hidden contract on the
   INSERT.
3. This is the write-side mirror of a reused-function entitlement check on
   the read side (if your corpus has one) — that pattern covers reused READ
   paths losing their access gate; this rule covers new WRITE paths losing
   their guard or omitting a downstream-required field.

## Anti-patterns (never do)

- Writing `UPDATE accounts SET enabled = ...` directly instead of calling
  the function that already owns that table's write-time side effects.
- Adding a 2nd, 3rd, or 4th independent `INSERT INTO users` across different
  routes/services without checking whether earlier occurrences of the exact
  same omission were already fixed once elsewhere in the codebase.
- Assuming "my feature's tests pass" proves the row is complete — the
  failure surfaces in a DIFFERENT consumer's code path, which your
  feature's test suite never exercises.
