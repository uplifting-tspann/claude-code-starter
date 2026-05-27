# claude/skills/

User-invocable skills — multi-step procedures Claude runs when you type
`/skill-name`. Each skill is a directory containing a `SKILL.md` (with
frontmatter describing the skill) and optionally helper scripts/templates.

## What's here

| Skill | What it does | Needs config? |
|-------|--------------|---------------|
| `consolidate-memory` | Reads recent session transcripts and updates persistent memory files (`recent-memory.md`, `long-term-memory.md`). Runs nightly or on demand. | No |
| `proof` | Structured verification protocol — exercises the change, captures evidence, emits the `Proof of Work` section the `proof-of-work` rule and Stop hook require. Use at the end of any coding task that modified files. | Optional — falls back to asking |
| `cross-repo-search` | Search a pattern in parallel across every project in your config. Returns results grouped by project. | Yes — refuses without config |
| `test-runner` | Run tests for a project — E2E, unit, smoke, or integration. Smart-targets based on the user's invocation. | Yes — refuses without config |
| `db-migrate` | Run a SQL migration against every environment for a project (prod first, then staging, etc.), update the schema file, clean up. | Yes — needs `database` block |
| `db-verify` | Verify that SQL references (function names, enum values, columns, tables) exist in the live DB before writing code that depends on them. Runs against every environment. | Yes — needs `database` block |
| `schema-diff` | Compare a project's documented schema file against the live DBs across every environment. Reports drift; generates fix scripts. | Yes — needs `database` block |
| `log-tail` | Tail logs for a deployed service — filtered by severity, time range, or pattern. Currently supports GCP Cloud Run; other cloud providers refuse cleanly. | Yes — needs `services[]` block |
| `code-cleanup` | 7-track cleanup pass on a project (dedup, type consolidation, dead code, circular deps, type strengthening, error handling, deprecated/AI slop). Scan first, fix high-confidence items, verify per-batch. | Optional — better with `lint_command` / `typecheck_command` |
| `repo-assessment` | Walks every project, reports staging/main divergence, CI health, open PRs, stale branches. Optionally auto-creates ready integration→production PRs where CI is green. | Yes — needs `git` block |

## The shared config: `~/.claude/projects-config.json`

Most skills read `~/.claude/projects-config.json` to know your projects'
paths, dev commands, test commands, database connection, deployed
services, and git branch model. The example schema lives at
[`claude/projects-config.json.example`](../projects-config.json.example).
Copy it to `~/.claude/projects-config.json` and edit before using
config-dependent skills.

The installer does NOT auto-copy this file — it's user-specific config.

Schema, abbreviated:

```json
{
  "projects": [
    {
      "name": "my-app",
      "path": "~/projects/my-app",
      "type": "fullstack" | "frontend" | "backend",
      "frontend": {
        "path": "...", "dev_command": "...", "dev_url": "...",
        "lint_command": "...", "typecheck_command": "..."
      },
      "backend":  {
        "path": "...", "dev_command": "...", "dev_url": "...",
        "lint_command": "...", "typecheck_command": "..."
      },
      "tests": { "unit": "...", "e2e": "...", "smoke": "...", "integration": "..." },
      "git": { "integration_branch": "staging", "production_branch": "main" },
      "database": {
        "engine": "postgres", "proxy_command": "...", "host": "...",
        "port": ..., "user": "...", "password_env": "DB_PASS",
        "schema_file": "...", "migrations_dir": "...",
        "environments": [ { "name": "prod", "db_name": "..." }, ... ]
      },
      "services": [
        { "name": "...", "kind": "cloud-run", "environment": "...",
          "cloud_project": "...", "service_name": "..." }
      ]
    }
  ],
  "search":  { "exclude_globs": [...], "include_extensions": [...] },
  "reports": { "output_dir": "~/projects/nightly-assessments" }
}
```

Every block is optional except `name` and `path`. Skills check for
their required blocks and refuse cleanly when missing — they don't
crash or guess.

## How skills get invoked

User types `/skill-name` in Claude Code. Claude loads the SKILL.md and
follows the procedure. Skill frontmatter:

```yaml
---
name: my-skill
description: One line shown in the skill list
disable-model-invocation: true   # Optional — prevents Claude from auto-invoking
allowed-tools: Bash(git *), Read, Write  # Optional — restricts the tool surface
---
```

## Adding your own skills

Create a directory, drop a `SKILL.md` in it. Keep skills:

- **Procedure-oriented.** Skills are recipes — "do X, then Y, then Z."
  If the answer is "Claude should always do X," that's a rule, not a skill.
- **Idempotent where possible.** Skills get re-run; that should be safe.
- **Explicit about destructive moves.** Confirm before deleting,
  force-pushing, or anything else with blast radius.
- **Graceful when config is missing.** Read `~/.claude/projects-config.json`
  if your skill needs project info, but degrade clearly (refuse, or ask
  the user) when it's absent. Don't crash on `KeyError`.
