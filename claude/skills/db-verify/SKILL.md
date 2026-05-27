---
name: db-verify
description: Verify that SQL references in code (function names, enum values, column names, tables) actually exist in the live database before writing code that depends on them. Reads ~/.claude/projects-config.json for connection details.
disable-model-invocation: true
---

# db-verify

Before writing any backend code that references database objects
(functions, enums, columns, tables), verify they exist. Prevents runtime
errors like `InFailedSqlTransaction` from misnamed functions or invalid
enum values.

## When to use

Before writing code that:
- Calls a SQL function: `SELECT function_name()`
- Inserts into an enum column: `INSERT INTO ... (type_col) VALUES ('new_value')`
- References a column that may not exist: `SELECT new_column FROM table`
- Creates a table that might already exist with different structure

## Step 0 — Read config

Read `~/.claude/projects-config.json`. Find the project by name (the user
may pass it; otherwise infer from cwd). Required: `project.database`
block with `host`, `port`, `user`, `password_env`, `environments[]`.

If config is missing or the project has no `database` block, refuse with
a pointer to the example. Don't proceed.

## Step 1 — Verify connection

If `database.proxy_command` is set, check:

```bash
lsof -i :<database.port>
```

If not running, instruct the user to start it:
> Database proxy not running. Start with: `<database.proxy_command>`

## Step 2 — Run the verification query

The user passes the object name (function / enum type / column / table).
Pick the right query template based on what they asked. For all queries,
substitute the actual db_name from `database.environments[]` (run against
every environment by default — drift between environments is the bug
this skill prevents).

### Function exists?

```bash
PGPASSWORD="${<password_env>}" psql \
  -h <host> -p <port> -U <user> -d <env.db_name> -c "
SELECT proname, pronargs FROM pg_proc
WHERE proname LIKE '%<search_term>%'
ORDER BY proname;
"
```

### Enum values?

```bash
PGPASSWORD="${<password_env>}" psql \
  -h <host> -p <port> -U <user> -d <env.db_name> -c "
SELECT enumlabel FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = '<enum_type_name>'
ORDER BY e.enumsortorder;
"
```

### Column exists?

```bash
PGPASSWORD="${<password_env>}" psql \
  -h <host> -p <port> -U <user> -d <env.db_name> -c "
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = '<table>'
AND column_name IN ('<col1>', '<col2>');
"
```

### Table exists?

```bash
PGPASSWORD="${<password_env>}" psql \
  -h <host> -p <port> -U <user> -d <env.db_name> -c "
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = '<table>';
"
```

## Step 3 — Run against every environment

Always run the verification against every environment in
`database.environments[]`, not just one. If `prod` has the object but
`staging` doesn't, that's a migration that ran on prod and was skipped
on staging — exactly the bug class this skill prevents.

Run the queries in parallel (one Bash invocation per environment).

## Step 4 — Report + fix

If the object doesn't exist in one or more environments:

- **Missing function**: find the correct name (often a typo or
  versioning issue); use that name in the code.
- **Missing enum value**: generate
  `ALTER TYPE <enum> ADD VALUE '<value>';` and tell the user to run the
  db-migrate skill against the missing environment(s).
- **Missing column**: generate `ALTER TABLE ... ADD COLUMN ...;` and
  hand off to db-migrate.
- **Missing table**: generate the full CREATE TABLE statement.

## Step 5 — Use savepoints for fallible DB calls

When calling a DB function that might not exist at runtime (e.g.,
during a gradual migration), wrap in a savepoint:

```python
nested = conn.begin_nested()
try:
    result = conn.execute(text("SELECT function_name()"))
    nested.commit()
except Exception:
    nested.rollback()
    # fallback logic
```

This prevents `InFailedSqlTransaction` errors from poisoning the outer
transaction. Verifying the object exists is better than savepoint-guarding,
but savepoints are the safety net when verification isn't possible.

## Common mistakes this prevents

1. Calling `generate_docs_invoice_number()` when the actual function is
   `generate_invoice_number()` — a typo + naming-convention guess.
2. Inserting `'client_invoice'` into an enum that only allows
   `'agreement'`, `'subscription'`, `'subscription_renewal'`.
3. Querying a `status` column that hasn't been added via ALTER TABLE
   yet on staging.
4. Using `::jsonb` cast syntax in `text()` strings — SQLAlchemy reserves
   `::` for named-param syntax. Use `CAST(... AS jsonb)` instead.
