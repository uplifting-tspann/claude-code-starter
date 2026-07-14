---
name: release-notes
description: Generate release notes from the git commits sitting on the integration branch but not yet on the production branch, for one repo or all of them, before opening a promotion PR. Reads ~/.claude/projects-config.json for repo paths and branch names.
disable-model-invocation: true
---

# release-notes

Generate release notes by diffing a project's **integration branch**
against its **production branch** — the set of changes that a promotion PR
would ship. Run this before opening that PR.

> **Stack assumption:** plain `git` plus (optionally) the `gh` CLI to open
> the PR. Nothing here is tied to a cloud provider or CI system.

## Step 0 — Read config

Read `~/.claude/projects-config.json`. This skill uses:

```json
{
  "name": "api",
  "path": "~/projects/api",
  "git": {
    "integration_branch": "staging",
    "production_branch": "main",
    "github_repo": "YOUR-ORG/api"
  }
}
```

- `integration_branch` — where day-to-day work lands. Default: `staging`.
- `production_branch` — what's live. Default: `main`.
- `github_repo` — `owner/repo`, only needed if the user asks you to open
  the PR. Optional.

If a project has no `git` block, fall back to `staging` → `main` and say
you're doing so. If the config file doesn't exist at all:

> No projects configured. Copy
> `claude-code-starter/claude/projects-config.json.example` to
> `~/.claude/projects-config.json` and add your repos.

## Step 1 — Pick the repo(s)

- User named a project → use it.
- User said "all" or didn't say → generate for **every** project that has
  unreleased changes, and skip (with a one-line note) the ones that don't.

## Step 2 — Fetch the latest refs

Always fetch first. Stale local refs produce release notes that are wrong
in the most embarrassing possible way — claiming things ship that already
shipped, or omitting things that haven't.

```bash
cd <project.path> && git fetch origin <production_branch> <integration_branch> 2>&1
```

## Step 3 — List the unreleased commits

```bash
cd <project.path> && git log \
  origin/<production_branch>..origin/<integration_branch> \
  --oneline --no-merges --format="%h %s (%an, %ar)"
```

If the output is empty: report **"No unreleased changes in `<project>`."**
and move on. Don't manufacture notes for an empty diff.

## Step 4 — Get the changed-file footprint

```bash
cd <project.path> && git diff --stat origin/<production_branch>..origin/<integration_branch>
```

This is what tells you which *areas* moved, which drives the testing
checklist in Step 6.

## Step 5 — Categorize

Read the commit subjects **and** the changed files — the files are the more
reliable signal; commit subjects lie about scope more often than diffs do.

| Category | Signals |
|---|---|
| **Features** | "add", "create", "implement", "new"; new route/page/component files |
| **Improvements** | "update", "improve", "enhance", "refactor" on existing files |
| **Bug Fixes** | "fix", "resolve", "patch", "correct"; small diffs to existing logic |
| **Infrastructure** | CI config, Dockerfile, deploy manifests, `.env`, build scripts |
| **UI/UX** | component files, CSS/Tailwind, layout, copy changes |
| **Database** | `.sql` files, schema files, migration directories |

A commit can land in more than one category — list it where it's most
useful to a reviewer, not where the keyword happened to match.

## Step 6 — Write the notes

```markdown
# Release Notes — <project name>
**Date:** <today>
**Branch:** <integration_branch> → <production_branch>
**Commits:** <count> since last release

## Features
- <plain-English description of what a user can now do> (<short_sha>)

## Improvements
- <what got better and for whom> (<short_sha>)

## Bug Fixes
- <what was broken, what now works> (<short_sha>)

## Infrastructure
- <what changed in build/deploy/config> (<short_sha>)

## Database
- <schema changes — call out anything requiring a migration on promote>

## Files Changed
- X files changed, Y insertions(+), Z deletions(-)
- Key areas: <directories / modules touched>

## Testing Checklist
- [ ] <specific thing to exercise, derived from the actual diff>
- [ ] <another, derived from the actual diff>
- [ ] <regression check on an area the diff touched indirectly>
```

Write descriptions for **a human deciding whether to promote**, not for
git. "Fix null deref in `parseUser`" is a commit message. "Profile page no
longer 500s for users with no avatar" is a release note.

**Call out anything that needs an action on promote** — a migration to run,
an env var to bind, a secret to rotate, a feature flag to flip. That's the
single highest-value line in the whole document.

## Step 7 — Offer next steps

Ask:

1. "Want me to open the promotion PR with these notes?"
   (`gh pr create --base <production_branch> --head <integration_branch>
   --title "..." --body-file <notes>` — needs `git.github_repo` or a repo
   with a configured remote.)
2. "Want a deeper testing checklist for any specific area?"
3. "Want me to check whether the E2E suite actually covers these changes?"

Don't open the PR unprompted.

## Multi-repo releases

When generating for all projects, lead with a combined summary so the user
can see the shape of the whole release at a glance:

| Repo | Commits | Key Changes |
|------|---------|-------------|
| api | 12 | New billing endpoints, partner sync fix |
| frontend-app | 5 | Settings redesign |
| docs-site | 0 | *No unreleased changes* |

Then the per-repo detail, skipping the empty ones.

## Anti-patterns (never do)

- Generating notes without `git fetch` first.
- Padding a thin release with filler bullets. Three real lines beat ten
  restated commit subjects.
- Copying commit subjects verbatim into the notes. Translate to user impact.
- Omitting the migration / env-var / flag actions needed on promote —
  that's the part that causes a bad deploy.
- Opening the PR without being asked.
