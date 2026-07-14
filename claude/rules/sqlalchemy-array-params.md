# SQLAlchemy text() Array Parameter Casting — Mandatory Rule

> **Applicability:** This rule only applies if you use SQLAlchemy `text()` against
> PostgreSQL. If you don't, delete this file. (The underlying lesson — that your
> query builder's parameter syntax can collide with your database's cast syntax —
> generalizes, but the specific fix below does not.)

## Core Rule

When using `ANY()` with a named parameter in SQLAlchemy `text()` against a
UUID column, **always use `ANY(CAST(:param AS uuid[]))`**. No exceptions.

## The Two Failure Modes

### Bare `ANY(:param)` — type mismatch (Bug 1)

```python
# ❌ WRONG — PostgreSQL error: operator does not exist: uuid = text
conn.execute(text("""
    UPDATE items SET status_id = :status_id
    WHERE id = ANY(:ids) AND parent_id = :parent_id
"""), {'status_id': sid, 'ids': ['uuid-string-here'], 'parent_id': pid})
```

SQLAlchemy passes Python string lists as `text[]` arrays. PostgreSQL cannot
compare a `uuid` column to a `text[]` array — it needs an explicit cast.

### Double-colon cast `ANY(:param::uuid[])` — SQLAlchemy parse error (Bug 2)

```python
# ❌ WRONG — SQLAlchemy treats :: as named-param syntax, mangling the query
conn.execute(text("""
    WHERE id = ANY(:ids::uuid[])
"""), {'ids': ['uuid-string-here']})
```

SQLAlchemy's `text()` parser interprets `::` as the start of a new named
parameter. The query gets split wrong and either errors at parse time or produces
garbage SQL.

### Correct pattern — `CAST()` function syntax

```python
# ✅ CORRECT — explicit CAST, no :: ambiguity
conn.execute(text("""
    UPDATE items SET status_id = :status_id
    WHERE id = ANY(CAST(:ids AS uuid[])) AND parent_id = :parent_id
"""), {'status_id': sid, 'ids': ['uuid-string-here'], 'parent_id': pid})
```

`CAST(:param AS uuid[])` is unambiguous to **both** SQLAlchemy's parser (no `::`
to misinterpret) and PostgreSQL's type system (an explicit `text[] → uuid[]`
cast).

The same applies to any other cast you'd be tempted to write with `::` inside a
`text()` block — e.g. `CAST(:payload AS jsonb)`, not `:payload::jsonb`.

## When This Rule Applies

Every time you write `ANY(:something)` inside a SQLAlchemy `text()` call where the
column is UUID:

- `WHERE id = ANY(...)`
- `WHERE user_id = ANY(...)`
- `WHERE parent_id = ANY(...)`
- Any UUID column matched against an array parameter

## Pre-Push Verification

Add a static scan test to your suite that greps the codebase for `::` following a
named parameter inside `text()` blocks, and fails if it finds one. Then run it
locally before pushing any commit that adds or modifies a `text()` block with
array parameters:

```bash
pytest tests/integration/test_sql_text_bind_safety.py -v
```

It takes under two seconds and prevents a CI round-trip.

## Why This Rule Exists

The same query shipped **twice in 10 minutes**. First without any cast — a 500 in
production on `operator does not exist: uuid = text`. Then "fixed" with
`::uuid[]` — which turned CI red on the static scan test that exists *precisely*
for this pattern.

Both bugs are prevented by the same `CAST()` form. Codifying it stops the next
`ANY()` clause from rediscovering either failure mode.
