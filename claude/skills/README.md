# claude/skills/

User-invocable skills — multi-step procedures Claude runs when you type
`/skill-name`. Each skill is a directory containing a `SKILL.md` (with
frontmatter describing the skill) and optionally helper scripts/templates.

## What's here

| Skill | What it does | Needs config? |
|-------|--------------|---------------|
| `consolidate-memory` | Reads recent session transcripts and updates persistent memory files (`recent-memory.md`, `long-term-memory.md`). Runs nightly or on demand. | No |
| `proof` | Structured verification protocol — exercises the change, captures evidence, emits the `Proof of Work` section the `proof-of-work` rule and Stop hook require. Use at the end of any coding task that modified files. | Yes — falls back to asking if missing |
| `cross-repo-search` | Search a pattern in parallel across every project in your config. Returns results grouped by project. | Yes — refuses without config |
| `test-runner` | Run tests for a project — E2E, unit, smoke, or integration. Smart-targets based on the user's invocation. | Yes — refuses without config |

## The shared config: `~/.claude/projects-config.json`

Three of the four skills read `~/.claude/projects-config.json` to know
where your code lives and how to drive it. The example schema lives at
[`claude/projects-config.json.example`](../projects-config.json.example).
Copy it to `~/.claude/projects-config.json` and edit before using
`cross-repo-search`, `test-runner`, or the full power of `proof`.

The installer does NOT auto-copy this file — it's user-specific config.

Schema, abbreviated:

```json
{
  "projects": [
    {
      "name": "my-app",
      "path": "~/projects/my-app",
      "type": "fullstack" | "frontend" | "backend",
      "frontend": { "dev_command": "...", "dev_url": "..." },
      "backend":  { "dev_command": "...", "dev_url": "..." },
      "tests": { "unit": "...", "e2e": "...", "smoke": "..." }
    }
  ],
  "search": {
    "exclude_globs": ["node_modules", "dist", ...],
    "include_extensions": ["py", "ts", "tsx", ...]
  }
}
```

## What's coming

Source `~/.claude/skills/` has additional skills (`db-migrate`,
`db-verify`, `schema-diff`, `log-tail`, `code-cleanup`,
`repo-assessment`) that need similar generalization — they're currently
hard-coded to specific Cloud SQL instances, repo paths, and service
names. Coming in follow-up passes; they'll likely extend the same
`projects-config.json` schema with `database` and `services` blocks.

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
- **Explicit about destructive moves.** Confirm before deleting, force-pushing,
  or anything else with blast radius.
- **Graceful when config is missing.** Read `~/.claude/projects-config.json`
  if your skill needs project info, but degrade clearly (refuse, or ask
  the user) when it's absent. Don't crash on `KeyError`.
