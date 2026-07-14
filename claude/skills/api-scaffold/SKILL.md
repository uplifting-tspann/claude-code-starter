---
name: api-scaffold
description: Scaffold a new backend API endpoint with the safety conventions already wired in — ID validation, enum checking, empty-string-to-NULL coercion, structured error logging with exc_info, DB-first-then-external-sync, and savepoints around fallible writes. Reads ~/.claude/projects-config.json for the backend path.
disable-model-invocation: true
---

# api-scaffold

Scaffold a CRUD endpoint that already has the conventions baked in, so the
bug classes below never get a chance to ship.

> **Stack assumption:** the worked example is **Flask + SQLAlchemy Core +
> PostgreSQL**. The *conventions* are the actual value here and they port
> to any stack — validate the path param before it reaches the query,
> validate enums against the real DB values, coerce `""` to `NULL` for
> typed columns, log with a stack trace, write locally before syncing
> externally, and wrap optional writes in a savepoint. If your backend is
> FastAPI / Express / Rails, keep the *rules* and translate the code.

## Step 0 — Read config

Read `~/.claude/projects-config.json` and find the project's backend:

```json
{
  "name": "api",
  "path": "~/projects/api",
  "backend": { "path": "backend" },
  "database": { "engine": "postgres", "schema_file": "database/schema.sql" }
}
```

Route files go in `<project.path>/<backend.path>/routes/`. If the project
has no `backend` block, ask the user where routes live before writing
anything.

## Step 1 — Gather requirements

Ask the user:

1. **Resource name** — plural, lowercase (`invoices`, `milestones`)
2. **Which database** — if the project has multiple engines configured
3. **Operations** — GET (list), GET (single), POST, PUT/PATCH, DELETE
4. **Auth required?** — almost always yes
5. **Enum columns?** — which fields are DB enums (you'll verify their real
   values in Step 2)
6. **External sync?** — does creating/updating this also call out to a
   third-party API (payments, e-sign, email)?
7. **Tenant scoping column** — the column that scopes rows to the caller's
   org/account/tenant. The examples below use `tenant_id`; substitute
   whatever yours is. **Every query must filter on it.**

## Step 2 — Verify the schema before writing SQL

**Do not guess at column names or enum values.** A wrong enum value is a
500 that only shows up in production.

```sql
-- Real enum values, from the real database:
SELECT enumlabel FROM pg_enum
JOIN pg_type ON pg_enum.enumtypid = pg_type.oid
WHERE pg_type.typname = '<your_enum_type>'
ORDER BY pg_enum.enumsortorder;

-- Real columns and their types:
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = '<your_table>';
```

Use the results to fill in `VALID_STATUSES` and `nullable_fields` below.
Column types drive `nullable_fields`: **any non-text column** (timestamp,
date, numeric, uuid, boolean) must have `''` coerced to `None`, because
Postgres rejects an empty string for those types — and frontends send `''`
for empty optional fields all day long.

If you genuinely can't reach the DB, leave the validation blocks commented
out with a `# TODO: verify against the live DB before enabling` marker
rather than shipping a guess.

## Step 3 — Scaffold the route file

Create `<backend.path>/routes/<resource>.py`.

### Imports and blueprint

```python
import logging
from flask import Blueprint, request, jsonify
from sqlalchemy import text

from auth import require_auth
from utils.validation import validate_uuid

logger = logging.getLogger(__name__)
bp = Blueprint('<resource>', __name__)


def get_engine():
    """Import lazily — avoids a circular import with the app factory."""
    from main import engine
    return engine
```

### GET (single) — validate the ID *before* the query

Passing an unvalidated string to a UUID column raises a `DataError` (a 500)
instead of returning a clean 404. Validate first, every time:

```python
@bp.route('/<resource_id>', methods=['GET'])
@require_auth
def get_resource(resource_id):
    user = request.user

    is_valid, _ = validate_uuid(resource_id, 'Resource ID')
    if not is_valid:
        # 404, not 400 — don't leak whether the ID format was wrong
        # vs. the row simply not existing.
        return jsonify({'error': 'Resource not found'}), 404

    try:
        with get_engine().begin() as conn:
            row = conn.execute(
                text("""
                    SELECT * FROM <table>
                    WHERE id = :id AND tenant_id = :tenant_id
                """),
                {"id": resource_id, "tenant_id": user.get('tenant_id')},
            ).mappings().first()

        if not row:
            return jsonify({'error': 'Resource not found'}), 404
        return jsonify(dict(row))

    except Exception as e:
        # exc_info=True is not optional — without the stack trace the
        # production log tells you nothing you can act on.
        logger.error(f"Error fetching <resource> {resource_id}: {e}", exc_info=True)
        return jsonify({'error': f'Failed to fetch <resource>: {str(e)}'}), 500
```

### POST (create) — validate enums, coerce empty strings

```python
# Filled in from Step 2 — the REAL enum values, not assumed ones.
VALID_STATUSES = {'draft', 'active', 'archived'}

# Every non-text column: timestamp, date, numeric, uuid, boolean.
NULLABLE_FIELDS = {'due_date', 'amount_cents', 'assigned_to_id'}


@bp.route('/', methods=['POST'])
@require_auth
def create_resource():
    user = request.user
    data = request.get_json() or {}

    required = ['name']
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({'error': f'Missing required fields: {", ".join(missing)}'}), 400

    # Validate the enum in the app so a bad value is a clean 400,
    # not a Postgres 500.
    if data.get('status') and data['status'] not in VALID_STATUSES:
        return jsonify({
            'error': f"Invalid status: {data['status']}. "
                     f"Must be one of: {', '.join(sorted(VALID_STATUSES))}"
        }), 400

    # '' is not NULL. Postgres will reject it for any typed column.
    for field in NULLABLE_FIELDS:
        if data.get(field) == '':
            data[field] = None

    try:
        with get_engine().begin() as conn:
            row = conn.execute(
                text("""
                    INSERT INTO <table> (name, status, due_date, tenant_id, created_by_user_id)
                    VALUES (:name, :status, :due_date, :tenant_id, :user_id)
                    RETURNING *
                """),
                {
                    "name": data['name'],
                    "status": data.get('status', 'draft'),
                    "due_date": data.get('due_date'),
                    "tenant_id": user.get('tenant_id'),
                    "user_id": user.get('user_id'),
                },
            ).mappings().first()

        return jsonify(dict(row)), 201

    except Exception as e:
        logger.error(f"Error creating <resource>: {e}", exc_info=True)
        return jsonify({'error': f'Failed to create <resource>: {str(e)}'}), 500
```

### PUT/PATCH (update) — allowlist the fields

Never build a SET clause from whatever keys the client happened to send.
An allowlist is the difference between "update the name" and "update the
`tenant_id`":

```python
ALLOWED_FIELDS = {'name', 'status', 'due_date', 'amount_cents'}


@bp.route('/<resource_id>', methods=['PUT'])
@require_auth
def update_resource(resource_id):
    user = request.user

    is_valid, _ = validate_uuid(resource_id, 'Resource ID')
    if not is_valid:
        return jsonify({'error': 'Resource not found'}), 404

    data = request.get_json() or {}

    if data.get('status') and data['status'] not in VALID_STATUSES:
        return jsonify({
            'error': f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}"
        }), 400

    params = {"id": resource_id, "tenant_id": user.get('tenant_id')}
    set_clauses = []

    for field in ALLOWED_FIELDS:
        if field in data:
            value = data[field]
            if field in NULLABLE_FIELDS and value == '':
                value = None
            params[field] = value
            # Safe interpolation: `field` came from ALLOWED_FIELDS, never
            # from user input. The VALUE is always a bound parameter.
            set_clauses.append(f"{field} = :{field}")

    if not set_clauses:
        return jsonify({'error': 'No valid fields to update'}), 400

    try:
        with get_engine().begin() as conn:
            row = conn.execute(
                text(f"""
                    UPDATE <table>
                    SET {', '.join(set_clauses)}, updated_at = NOW()
                    WHERE id = :id AND tenant_id = :tenant_id
                    RETURNING *
                """),
                params,
            ).mappings().first()

        if not row:
            return jsonify({'error': 'Resource not found'}), 404
        return jsonify(dict(row))

    except Exception as e:
        logger.error(f"Error updating <resource> {resource_id}: {e}", exc_info=True)
        return jsonify({'error': f'Failed to update <resource>: {str(e)}'}), 500
```

## Step 4 — Add the cross-cutting patterns the endpoint needs

### External sync — write locally FIRST, sync AFTER

If the external call goes first and fails, the user's data is gone. Save
it, then sync, and surface a non-fatal warning if the sync fails:

```python
        with get_engine().begin() as conn:
            row = conn.execute(text("UPDATE ..."), params).mappings().first()
        # DB write is committed. The user's change is safe no matter what
        # happens next.

        warning = None
        try:
            external_api.sync(...)
        except Exception as e:
            logger.warning(f"External sync failed (non-fatal): {e}")
            warning = 'Saved. External sync will retry automatically.'

        response = dict(row)
        if warning:
            response['warning'] = warning
        return jsonify(response)
```

### Savepoints — for optional writes inside a bigger transaction

If you `try/except` around a DB write and keep going on the **same
connection**, Postgres has already marked the transaction aborted — every
later query on that connection fails with `InFailedSqlTransaction`. A
savepoint scopes the rollback to just the optional write:

```python
        with get_engine().begin() as conn:
            # Optional write — an audit-log failure must not kill the request.
            nested = conn.begin_nested()
            try:
                conn.execute(text("INSERT INTO audit_log ..."), {...})
                nested.commit()
            except Exception as e:
                nested.rollback()          # rolls back ONLY the savepoint
                logger.warning(f"Audit log failed (non-fatal): {e}")

            # The connection is still usable — this succeeds.
            conn.execute(text("UPDATE <table> SET ..."), {...})
```

### Array parameters — use `CAST()`, never `::`

SQLAlchemy's `text()` parser reads `::` as the start of a named parameter
and mangles the query. And a bare `ANY(:ids)` passes a `text[]`, which
Postgres won't compare to a `uuid` column:

```python
# ❌ ANY(:ids)          → operator does not exist: uuid = text
# ❌ ANY(:ids::uuid[])  → SQLAlchemy misparses the `::`
# ✅
text("SELECT * FROM <table> WHERE id = ANY(CAST(:ids AS uuid[]))")
```

## Step 5 — Register the blueprint

```python
# main.py
from routes.<resource> import bp as <resource>_bp
app.register_blueprint(<resource>_bp, url_prefix='/api/<resource>')
```

## Step 6 — Wrap up

1. Confirm the enum values and nullable columns came from the **real
   database** (Step 2), not from assumption. If you couldn't check, say so
   out loud rather than leaving it implicit.
2. Exercise each new route with a real request — a happy path and at least
   one error case (invalid ID → 404; bad enum → 400). "It imports" is not
   verification.
3. Add tests for the new endpoints.

## Anti-patterns (never do)

- Passing a path param straight into a UUID column without validating —
  that's a 500 where a 404 belonged.
- Guessing enum values instead of querying `pg_enum`.
- Passing `''` to a timestamp/numeric/uuid column.
- `logger.error(f"...")` with no `exc_info=True` — a log line with no
  stack trace is a log line you can't act on.
- Returning `{'error': 'An internal error occurred'}` — useless to the
  user *and* to the person debugging it.
- Calling the external API before the DB write.
- Swallowing a DB exception and continuing on the same connection without
  a savepoint.
- Building a SET clause from arbitrary client keys instead of an allowlist.
- Forgetting the tenant-scoping predicate on any query. Every row read or
  written must be scoped to the caller.
