---
name: cross-repo-search
description: Search a pattern in parallel across every project listed in ~/.claude/projects-config.json. Use when you need to find where something is defined or referenced and it could live in any of several repos.
disable-model-invocation: true
---

# cross-repo-search

Search a pattern across all your projects in parallel. Reads
`~/.claude/projects-config.json` to know which repos exist and where.

The user provides a search term (string or regex) when invoking.

## Step 0 — Read config

Read `~/.claude/projects-config.json`. Expected shape (see
`claude-code-starter/claude/projects-config.json.example`):

```json
{
  "projects": [
    { "name": "...", "path": "~/projects/..." },
    ...
  ],
  "search": {
    "exclude_globs": ["node_modules", "dist", ...],
    "include_extensions": ["py", "ts", "tsx", ...]
  }
}
```

If the file doesn't exist OR `projects` is empty:

> No projects configured. Copy
> `claude-code-starter/claude/projects-config.json.example` to
> `~/.claude/projects-config.json` and edit it to list your projects,
> then re-invoke this skill.

Stop and report this — don't proceed.

## Step 1 — Build the search plan

For each project in `projects[]`, plan a `Grep` call against `project.path`:

- Pattern: the user's search term
- Exclude: every glob in `search.exclude_globs` (translated to the
  Grep tool's exclude syntax, or `-g '!node_modules/**'` etc.)
- Include: filter by `search.include_extensions` when the user hasn't
  asked for "everything" — when in doubt, include all configured
  extensions

## Step 2 — Run all searches in parallel

Issue all `Grep` tool calls in a single message (parallel). Each call
targets one project's path.

Expand `~` in `project.path` to `$HOME` before passing to the tool.

## Step 3 — Format results

Group output by project:

```
### project-name
file/path/A:line: match excerpt
file/path/B:line: match excerpt
(N matches)

### other-project
file/path/X:line: match excerpt
(M matches)

### project-with-no-matches
(no matches)
```

At the end, summarize: `Total: N matches across M projects.`

## Step 4 — When the user wants different scope

- "search only in <project>": skip every other project; run a single Grep.
- "search everywhere including node_modules": ignore exclude_globs for
  this run only.
- "search only X file types": narrow include_extensions for this run.

These are session overrides — don't edit `projects-config.json`.

## Anti-patterns (never do)

- Running searches sequentially when parallel works. Parallel is the whole point.
- Hardcoding a project path that isn't in `projects-config.json`. If the
  user has a new repo, ask them to add it to the config first.
- Returning raw, ungrouped grep output. Always group by project.
