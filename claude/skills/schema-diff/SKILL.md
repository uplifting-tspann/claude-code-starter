---
name: schema-diff
description: Compare a project's documented schema file against the live PostgreSQL databases to find drift between documentation and reality. Reads ~/.claude/projects-config.json for the schema file path and per-environment DB connection details.
disable-model-invocation: true
---

# schema-diff

Compare a documented schema file (e.g., `database/schema.sql`) against
the actual live database schema across every environment. Catches:

- Migrations that ran on one environment but not another
- Hand-applied changes that weren't reflected in the schema file
- Schema file additions that haven't actually been applied

## Step 0 — Read config

Read `~/.claude/projects-config.json`. Find the project by name. Need:

```json
"database": {
  "host": "...", "port": ..., "user": "...", "password_env": "...",
  "schema_file": "backend/database/schema.sql",
  "environments": [
    { "name": "prod",    "db_name": "..." },
    { "name": "staging", "db_name": "..." }
  ]
}
```

If config or `database` block is missing, refuse with a pointer to the
example. Don't proceed.

## Step 1 — Verify proxy / connection

If `database.proxy_command` is set, check `lsof -i :<port>`. If not
running, instruct the user to start it.

## Step 2 — Read the schema file

Read `<project.path>/<database.schema_file>`. Parse out:

- All `CREATE TABLE` statements (table name + columns + types + constraints)
- All `CREATE TYPE ... AS ENUM` statements (enum name + values)
- All `CREATE INDEX` statements (index name + table + columns)

If the file doesn't exist, report and stop — there's nothing to
compare against.

## Step 3 — Query every live database in parallel

For each environment in `database.environments[]`, run all three
introspection queries in parallel:

### Tables and columns

```bash
PGPASSWORD="${<password_env>}" psql \
  -h <host> -p <port> -U <user> -d <env.db_name> -t -A -c "
SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;
"
```

### Enum types

```bash
PGPASSWORD="${<password_env>}" psql \
  -h <host> -p <port> -U <user> -d <env.db_name> -t -A -c "
SELECT t.typname, e.enumlabel
FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
ORDER BY t.typname, e.enumsortorder;
"
```

### Indexes

```bash
PGPASSWORD="${<password_env>}" psql \
  -h <host> -p <port> -U <user> -d <env.db_name> -t -A -c "
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;
"
```

## Step 4 — Compare and report

### Schema file vs. each environment

| Issue | Table | Column/Type | schema_file | Live DB | Action |
|-------|-------|-------------|-------------|---------|--------|
| Missing column | accounts | new_field | defined | missing | Apply migration |
| Extra column | users | old_field | not defined | exists | Update schema_file or drop |
| Type mismatch | items | role | enum | varchar | Investigate |
| Missing enum value | — | item_status | has 'archived' | missing 'archived' | ALTER TYPE ADD VALUE |

### Environment parity (env A vs. env B)

| Issue | Table | Column | env A | env B | Action |
|-------|-------|--------|-------|-------|--------|
| Missing column | accounts | new_field | exists | missing | Run migration on env B |

The second comparison matters as much as the first. Schema_file
drift means docs are wrong; env-to-env drift means production behavior
will differ from staging behavior, which is the more dangerous bug.

## Step 5 — Generate fix scripts

For each issue, generate the appropriate SQL fix:

- Missing column → `ALTER TABLE ... ADD COLUMN ...`
- Missing enum value → `ALTER TYPE ... ADD VALUE ...`
- Schema_file out of date → show the updated CREATE TABLE block to paste in

Generate fixes per environment so the user can pass them to db-migrate.

## Step 6 — Summary

Report:
- Environments checked: N
- Tables checked: X
- Columns checked: Y
- Enums checked: Z
- **Drift found: M issues**
  - schema_file vs. live: A
  - env-to-env: B
- Fix scripts generated: C (link to where each lives)

If no drift, confirm everything is in sync — that's a useful signal too.

## Anti-patterns (never do)

- Auto-applying fixes. This skill diagnoses; db-migrate applies.
- Checking only one environment. Drift detection requires comparing across.
- Ignoring schema_file drift because "the live DBs all match" — the
  schema file is the documentation; mismatched docs lead to bugs
  weeks later.
