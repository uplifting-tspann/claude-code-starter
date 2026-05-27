---
name: db-migrate
description: Run a database migration safely against every environment for a project (prod + staging + ...), then update the schema file and clean up the migration file. Reads ~/.claude/projects-config.json for connection details.
disable-model-invocation: true
---

# db-migrate

Run a database migration with full safety checks. Enforces the workflow:
verify, run on production, run on staging, update schema file, clean up.

## Usage

User provides:
- Project name (matches `projects[].name` in config)
- Migration file path (a `.sql` file)

## Step 0 — Read config

Read `~/.claude/projects-config.json`. Find the project by name. Expected
shape under `project.database`:

```json
{
  "engine": "postgres",
  "proxy_command": "cloud-sql-proxy ... --port=5433",
  "host": "127.0.0.1",
  "port": 5433,
  "user": "admin",
  "password_env": "DB_PASS",
  "schema_file": "backend/database/schema.sql",
  "environments": [
    { "name": "prod",    "db_name": "myapp_prod" },
    { "name": "staging", "db_name": "myapp_staging" }
  ]
}
```

If the project is missing OR has no `database` block, refuse:

> Project "<name>" has no database config. Add a `database` block to
> ~/.claude/projects-config.json (see
> claude-code-starter/claude/projects-config.json.example).

Stop and report — don't proceed.

## Step 1 — Verify proxy / connection

If `database.proxy_command` is set, check that something is listening on
`database.port`:

```bash
lsof -i :<port>
```

If not running, tell the user:

> Database proxy not running on port <port>. Start it with:
> `<database.proxy_command>`

Do NOT proceed until the connection is confirmed.

If no `proxy_command` is set, assume the connection is direct and skip
this step.

## Step 2 — Read and review the migration

Read the SQL file. Display its contents. Ask the user to confirm before
running.

List the target environments from `database.environments[]`. The user
sees exactly what will run, where, in what order.

## Step 3 — Run on production first

Production runs first by convention: if it fails, you stop and never
touch staging (the inverse — staging-first — encourages drift when
something works there but fails in prod).

Find the environment named `"prod"` (or `"production"` if that's what
the config uses; fall back to the first environment if neither label
exists). Then:

```bash
PGPASSWORD="${<database.password_env>}" psql \
  -h <database.host> -p <database.port> -U <database.user> \
  -d <prod env db_name> -f <MIGRATION_FILE>
```

Verify the migration succeeded. If it fails, STOP and report. Do NOT
proceed to staging.

## Step 4 — Run on every other environment

For each remaining environment (staging, demo, etc.), run the same
migration:

```bash
PGPASSWORD="${<database.password_env>}" psql \
  -h <host> -p <port> -U <user> -d <env db_name> -f <MIGRATION_FILE>
```

**Schema parity is the whole point.** Never skip environments. Drift
between environments causes deployment failures later.

Verify success on each.

## Step 5 — Update the schema file

If the migration alters schema (CREATE/ALTER TABLE, CREATE TYPE, etc.):

- Read `<project.path>/<database.schema_file>`
- Update it to reflect the new state (add the new column, new enum
  value, new table, etc.)
- This file is the authoritative schema reference; without updating it,
  the schema-diff skill will report drift

If the migration is data-only (INSERT/UPDATE/DELETE), skip this step.

## Step 6 — Delete the migration file

After every environment succeeds, delete the SQL file:

```bash
rm <MIGRATION_FILE>
```

Rationale: migration files are temporary by design — they've been
applied. Keeping them around invites someone to re-run them. The schema
file + migration history (in version control) is what persists.

Exception: numbered migration files in a tracked migrations directory
(`001_initial.sql`, `002_add_users.sql`, ...) are part of the migration
history chain — keep those. Ad-hoc fix files (`fix_foo.sql`,
`cleanup_bar.sql`) are temporary — delete.

## Step 7 — Summary

Report:
- Migration file (path + brief description)
- Per-environment result (✓ / ✗)
- Schema file updated (yes / no / not needed)
- Migration file deleted (yes / no — kept because tracked migration)
- Anything to manually verify (e.g., "run `\d <table>` to confirm the
  new column")

## Anti-patterns (never do)

- Running staging before prod. Prod first; if it fails, you stop.
- Skipping any environment. All-or-nothing.
- Updating the schema file when the migration was data-only.
- Deleting numbered migration files in a tracked directory.
- Running a migration before reading + displaying its contents to the
  user for confirmation.
