# claude/memory/

Templates and examples for Claude Code's persistent memory system. The
*model* is explained in detail in [WHY.md → "The memory model"](../../WHY.md#the-memory-model);
this directory provides the **shape** of the actual files Claude writes.

> **Important:** Nothing in this directory gets auto-installed into
> `~/.claude/projects/<your-project>/memory/`. Memory belongs to *you*,
> not the template — it accumulates as you work. These files exist so
> you (and Claude, when invoking the auto-memory system) know what
> "good" looks like.

## The two layers

```
~/.claude/projects/<your-project>/memory/
├── MEMORY.md                  ← one-line index, loaded into every conversation
├── feedback_no_auto_commit.md ← per-topic file: full content
├── user_role.md               ← per-topic file
├── project_q4_launch.md       ← per-topic file
└── reference_grafana_dash.md  ← per-topic file
```

- `MEMORY.md` — the index. Each line points at one per-topic file. Loaded
  into every conversation. Keep it concise (~200 lines max) — lines
  beyond that get truncated.
- Per-topic files — full content for one memory each. Loaded *on demand*
  when relevant to the current conversation.

## The four types

Every per-topic file declares a `type` in its frontmatter:

| Type | What it captures | Example trigger |
|------|------------------|-----------------|
| **user** | Identity, role, what they know, goals | "I'm a data scientist" |
| **feedback** | How the user wants work done, what to avoid, what worked | "Don't auto-commit" |
| **project** | Active work state, deadlines, who's doing what | "We're freezing merges Thursday" |
| **reference** | Pointers to external systems (where to find X) | "Bugs tracked in Linear project FOO" |

See [WHY.md → "The four types"](../../WHY.md#the-four-types) for the
when-to-use-which guide.

## Frontmatter format

```markdown
---
name: short-kebab-case-slug
description: One-line summary used to decide relevance in future conversations. Be specific.
metadata:
  type: user | feedback | project | reference
---

Body content. For feedback/project, structure as:
1. The rule or fact (one sentence)
2. **Why:** the reasoning
3. **How to apply:** when this kicks in

Link related memories with [[their-name]] — uses the `name:` slug.
```

## Examples in this directory

| File | Demonstrates |
|------|--------------|
| `MEMORY.md.example` | What a well-curated index looks like |
| `templates/user-example.md` | A `user`-type memory (minimal) |
| `templates/feedback-example.md` | A `feedback`-type memory (with Why + How to apply) |
| `templates/project-example.md` | A `project`-type memory (with date + status) |
| `templates/reference-example.md` | A `reference`-type memory (external pointer) |

Read them. Don't copy them into your own memory dir as-is — they're
illustrative.

## When to consolidate

Memory bloats over time. Run [`/consolidate-memory`](../skills/consolidate-memory/SKILL.md)
regularly — nightly via a scheduled task is ideal; weekly is the minimum
for active work.

The skill reads recent session transcripts, extracts signal, and
collapses overlapping entries. Without it, the index drifts and the
per-topic files duplicate each other.

## What NOT to save

From [WHY.md → "What NOT to save"](../../WHY.md#what-not-to-save):

- Code patterns, file paths, conventions — derive from the codebase.
- Git history — `git log` is authoritative.
- Debugging solutions — the fix is in the code; the commit message has
  the context.
- Ephemeral task details — in-progress work belongs in workstream files
  or a todo list, not memory.

These exclusions apply *even when the user explicitly asks you to save*.
If they ask for a memory of a PR list or activity summary, push back —
ask what was *surprising* or *non-obvious* about it. That's the part
worth keeping.
