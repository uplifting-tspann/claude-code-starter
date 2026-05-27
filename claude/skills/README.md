# claude/skills/

User-invocable skills — multi-step procedures Claude runs when you type
`/skill-name`. Each skill is a directory containing a `SKILL.md` (with
frontmatter describing the skill) and optionally helper scripts/templates.

## What's here (v0.1)

| Skill | What it does |
|-------|--------------|
| `consolidate-memory` | Reads recent Claude session transcripts and updates persistent memory files (`recent-memory.md`, `long-term-memory.md`). Runs nightly or on demand. |

## What's coming

The source `~/.claude/skills/` has ~10 more skills, but they're all currently
hard-coded to specific repo paths (e.g., `/Users/tunky-mini/projects/hub/`).
Shipping them raw would make the template feel like personal dotfiles, so
they're being generalized in follow-up passes:

| Skill | What it will do | Status |
|-------|-----------------|--------|
| `proof` | Structured verification protocol — exercises the change, captures evidence, emits a Proof of Work section | Needs path abstraction |
| `code-cleanup` | 7-track cleanup pass (dedup, dead code, type strengthening, etc.) | Needs repo-path abstraction |
| `cross-repo-search` | Search a pattern across all your repos in parallel | Needs repo list config |
| `test-runner` | Run E2E + unit tests across repos with smart targeting | Needs repo list config |
| `db-migrate` | Run a SQL migration safely against prod + staging, update schema, clean up | Needs DB connection config |
| `db-verify` | Verify SQL references (functions, enums, columns) exist before writing code | Needs DB connection config |
| `schema-diff` | Compare `database/schema.sql` against live DB to find drift | Needs DB connection config |
| `log-tail` | Tail Cloud Run logs with smart filtering | GCP-specific; needs service list config |
| `repo-assessment` | Nightly assessment — staging/main divergence, CI health, ready-to-promote PRs | Needs repo list config |

Most of these will be generalized by extracting the hard-coded paths into a
shared config (e.g., `~/.claude/projects-config.json`) that each skill reads.

## How skills get invoked

User types `/skill-name` in Claude Code. Claude loads the SKILL.md and follows
the procedure. Skill frontmatter:

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
- **Explicit about destructive moves.** Confirm before deleting, force-pushing,
  or anything else with blast radius.
