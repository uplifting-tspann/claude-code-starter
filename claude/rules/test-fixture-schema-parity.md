# Test-Fixture Schema Parity — Mandatory Check When SQL or Schema Changes

> **Applicability:** This rule applies if you run integration tests against a
> **real database** whose schema is built from hand-maintained fixture/baseline
> files (rather than by replaying your full production migration history). If
> your test DB is built by replaying every production migration, this whole class
> of drift can't happen — delete this rule. The worked examples below use
> Python/pytest/Postgres, but the rule is stack-agnostic.

## Core Principle

**Your integration-test database is NOT production.** It is built from a set of
hand-crafted schema fixture files ("baselines") plus a short, explicit list of
migrations registered in your test config. **Production migrations are not
replayed.**

So a column that has lived in prod for weeks can be **silently missing from the
test schema** — invisible until some service path starts referencing it during a
test run, and then the deploy gate goes red on `UndefinedColumn`.

This rule's job is to fire a check at the moment a gap is **created**, not when
the gap eventually bites a build.

## Triggers

Run the check whenever any of these happens:

1. **A SQL block is modified** in a service or route file — a new column added to
   an `INSERT` column list, a new column selected, a new `WHERE` predicate.
2. **A new migration** adds a column, type, enum value, or table on a table any
   integration test touches.
3. **A new service function** reads or writes a fixture-covered table.
4. **An integration-test failure** with `UndefinedColumn` / `UndefinedTable` /
   an invalid-enum-value error — the root cause is almost always fixture drift,
   not a production bug.

## The Check

1. List every column / type / enum value referenced by the new or modified SQL.
2. **Identify which test engine/fixture the test uses.** If you have more than
   one test database (e.g. one per service), this determines which baselines are
   applied. Getting this step wrong is the single most common way the check
   passes while the test still fails — see below.
3. Open your test config (e.g. `conftest.py`) and read the **registered baseline
   list for that engine**. That list — not the fixtures *directory* — is the set
   of files that will actually be applied.
4. `grep` each column / type / value against **only the files in that list**.
5. For anything missing: either add it to a baseline already in that engine's
   list, or register the owning baseline in that engine's list. Same commit as
   the code change.

## Baselines are engine-scoped — grep the LIST, not the DIRECTORY

If your setup has more than one test-database fixture (e.g. `db_a_engine` and
`db_b_engine`), each has **its own registered baseline list**.

**A file sitting in the fixtures directory is inert unless it is registered for
your engine.** This is the trap: you grep the directory for `partners`, you find
it in some baseline file, you conclude "covered" — but that baseline is
registered only for the *other* engine. The grep passed. The test still breaks.

Some baselines are deliberately registered for **both** engines. That is a
supported pattern precisely because both need them — every such file must be
fully `IF NOT EXISTS`, so a second apply is a no-op.

If your test needs a table owned by a baseline in the *other* engine's list,
**register that baseline in your engine's list too**. Do NOT duplicate its
`CREATE TABLE` into a new file — that races (see "baselines must compose").

## A green CI does NOT prove your fixture coverage is right

Watch for this asymmetry: **in CI, multiple engines often share ONE database**
(e.g. both read the same `TEST_DB_URL` sidecar), so whichever initializes first
applies its baselines into the shared DB — and the **union of all baselines**
ends up present. **Locally, each engine spins up its own isolated container**, so
the schemas are disjoint.

The consequence: a test that depends on a baseline registered for the *other*
engine **passes in CI by accident** and fails locally.

So: **when local and CI disagree, believe local.** Local is the honest signal
(isolated schema, only your engine's baselines). CI is the permissive one. Do not
"fix" a local-only failure by dismissing it as a local quirk — it is telling you
the baseline list is wrong, and the CI pass is the bug.

## RUN THE SUITE. An unrun test is unverified code.

If you write or touch an integration test, or change SQL an integration test
covers, **run the suite before you commit.** Not the grep — the suite.

```bash
# example (pytest + a marker for the real-DB layer)
pytest -m integration -q                    # full suite
pytest -m integration -q -k "<your area>"   # faster inner loop
```

Check the container runtime is up first. If it's down, **start it** rather than
falling back to the grep. The grep is the degraded path, not the default one.

Nearly every incident this rule exists to prevent was authored while the
container runtime was down and therefore **never actually executed**.

### If the container runtime genuinely cannot run

Most suites **auto-skip** the real-DB layer when the daemon is unreachable. It is
tempting to read that green-looking run as "the DB layer is fine / not my concern
this turn." **That is exactly the trap.** A skipped suite verified nothing.

The static baseline-grep above is not a substitute for running the suite — it is
the *only* safety net you have left when you can't run it. A runtime-down turn
makes the grep **mandatory, not optional.**

- If your change adds/uses a column, enum value, table, or function: do the
  baseline grep by hand and add the additive ALTER — **even though, especially
  because, you cannot run the suite.**
- If you author a **new** integration test and cannot run it: it is **unverified
  code.** Before committing, open the owning baseline file(s) and confirm that
  **every** table and column your test seeds or queries actually exists there.
  Read the `CREATE TABLE`. Don't assume.
- **Say so out loud.** State
  `Not verified: integration DB layer (container runtime down) — baselines grepped by hand`
  in your Proof of Work, so the verification gap is visible **before** CI, not
  discovered by a red deploy gate.

## How to Fix Missing Coverage

Two fixes. Pick by *why* the object is missing:

**(a) The object exists in no baseline at all** → add an additive
`IF NOT EXISTS` statement to the baseline that owns the table, in your engine's
list.

**(b) The object exists in a baseline registered for the OTHER engine** →
register that whole baseline file in your engine's list too. Do **not** copy its
`CREATE TABLE` into a new file — that races. Add a comment saying why it's in
both lists.

Always additive, always `IF NOT EXISTS`. Baselines must compose with each other
and with future baselines — if engines share one CI database, any baseline that
does a bare `CREATE TABLE` or a non-additive `ALTER` will race with another.

```sql
-- ✅ Always safe — composes with everything
ALTER TABLE <table> ADD COLUMN IF NOT EXISTS <col> <type>;

-- ✅ For new enum values
ALTER TYPE <enum_type> ADD VALUE IF NOT EXISTS '<value>';

-- ✅ For tables only created by recent migrations
CREATE TABLE IF NOT EXISTS <table> (...);
```

**Match the column type exactly to the production migration.** If prod says
`NUMERIC(10,2) NULL`, the baseline says the same. Type mismatches surface later
as cast errors.

## What NOT to Do

- **Don't append the production migration to the test config's migration list.**
  That's the wrong fix. It has been tried and bit: the production migration
  assumes other prod tables/columns the test sidecar doesn't have. Baselines
  exist precisely to avoid that coupling.
- **Don't add a bare `CREATE TABLE`** (without `IF NOT EXISTS`) for a table
  another baseline already creates. They'll race.
- **Don't add a non-additive `ALTER`** (`ALTER COLUMN … TYPE …`, `DROP COLUMN`,
  `RENAME COLUMN`) to a baseline. Baselines run in arbitrary order relative to
  each other; only strictly additive `IF NOT EXISTS` operations are safe.

## Fixture Coverage Report

When SQL was modified or a covered migration was added, the `Proof of Work:`
block MUST include a `Fixture Coverage:` bullet naming the baseline(s) checked
and the result. This is the audit trail — if the bullet is missing, the check was
skipped.

**Name the engine.** "grepped X against billing_baseline.sql" is not auditable on
its own — that file could be registered for one engine and not the other. Say
which engine's list you checked. And if you ran the suite, say so — a run beats a
grep and should be reported as such.

```
Proof of Work:
- What changed: added pre_approved_overage_hours to the create_instance INSERT
- Fixture Coverage: grepped pre_approved_overage_hours against the billing-engine
  baseline list (billing_baseline.sql + defaults_baseline.sql) — missing in both;
  added an additive ALTER to defaults_baseline.sql to match migration 092.
  Ran `pytest -m integration -k billing` — green.
- How I verified: ...
- What I observed: ...
- Not verified: ...
```

If no baseline change was needed:

```
- Fixture Coverage: grepped 3 new columns against the billing-engine baseline
  list — all present, no baseline change needed
```

For migrations that don't touch any fixture-covered table:

```
- Fixture Coverage: not applicable — table `foo` is admin-only, not covered by
  any integration test
```

## Why This Rule Exists

- **A composition bug:** one baseline's bare `CREATE TABLE` raced another
  baseline's columns on the shared CI database. Fix: everything additive,
  everything `IF NOT EXISTS`.
- **A six-day latent gap:** a migration added a column to prod. Six days of green
  CI followed — because no test path referenced it yet. Then a service path
  started writing that column, the integration layer went red on
  `UndefinedColumn`, and the deploy gate blocked. The bug had been latent the
  whole time.
- **An unrun test:** a new integration test seeded a table with a `tenant_id`
  column, but the baseline's version of that table is scoped by a text slug and
  has no `tenant_id` at all. The **test itself** was wrong. It was authored while
  the container runtime was down and therefore never executed.
- **The engine-scoping trap:** the first full local run after the container
  runtime was fixed came back **813 passed / 11 failed / 30 errors.** Six suites
  used engine B but depended on tables owned by baselines registered **only for
  engine A**. They had been green in CI the entire time, purely because CI puts
  both engines in one shared database. An earlier version of this rule said "grep
  the fixtures *directory*" — which finds the table and says "covered," which is
  wrong. Hence: grep the **registered list**, and don't trust a green CI.

The pattern: the latency between "a column lands in prod" and "some code path
references it during a test run" can be arbitrary, and the gap is invisible until
it bites. This rule makes the check mandatory at the moment the gap is created —
before the latency window opens.

The second pattern: **an unrun test is unverified code.** Both of the
worst incidents were authored while the container runtime was down.

## Interaction with Other Rules

- **`verify-db-objects.md`** — sibling rule. That one verifies against the live
  **production** DB before writing SQL ("does this function exist?"). This one
  verifies against the **test** schema ("does this column exist in the schema CI
  applies?"). Both checks belong; they catch different failure modes.
- **`proof-of-work.md`** — the `Fixture Coverage:` bullet is a sub-line inside
  the existing `Proof of Work:` block, not a new top-level section. It fires only
  when SQL/schema was touched.
- **`commit-discipline.md`** — when authorized to commit, the baseline ALTER goes
  in the **same commit** as the service-code or migration change. Splitting them
  is exactly the lag this rule prevents.

## Anti-Patterns (Never Do)

- Skipping the `Fixture Coverage:` bullet because "I'm sure the baseline already
  has it" — the grep takes 5 seconds and is the audit trail.
- Appending the production migration to the test config's migration list instead
  of adding a baseline ALTER — wrong fix, and it has bitten repeatedly.
- Adding a bare `CREATE TABLE` to a baseline without `IF NOT EXISTS`.
- Type-mismatching the baseline ALTER against the production column.
- **Grepping the fixtures directory instead of your engine's registered baseline
  list** — a file in that directory is inert unless registered for the engine your
  test uses. This is the check passing while the test still fails.
- **Dismissing a local-only failure as "a local quirk" because CI is green** —
  CI may merge engines into one DB and is therefore the *permissive* signal.
  Local is the honest one. When they disagree, believe local.
- **Copying a `CREATE TABLE` into a second baseline** because the other engine
  needs it — register the *existing* baseline in that engine's list instead.
- **Committing an integration test you never executed.** An unrun test is
  unverified code, and it is how the worst incidents here were authored.
