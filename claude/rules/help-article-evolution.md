# Help Articles — Mandatory Evolution Rule

> **Applicability:** This rule only applies if your project publishes user-facing help content (a knowledge base, public docs site, in-app help articles, etc.). If your project doesn't, delete this rule from `~/.claude/rules/`. The rest assumes you do.

## Core Principle

Help content — whatever its storage shape (database-driven articles, static markdown files in a docs site, in-app tooltips backed by JSON) — is a living artifact that MUST evolve with every feature addition, bug fix, or behavioral change. This is automatic — not reminder-dependent. Help content drift is a bug.

## After Every Feature, Bug Fix, or Behavioral Change

Before considering any work complete, answer these questions:

1. **Does new help content need to exist?** If this change introduces a user-facing concept, workflow, or capability not already documented — draft a new article. If unsure, **ask the user**.
2. **Which existing articles mention this feature?** Search your help-content store by title, slug, or keyword. Update any that reference the old behavior, copy, or UI.
3. **Which existing guides point to this feature?** If you have static guide entries (e.g., a curated `guides.ts` array in code), check those too. Update titles, descriptions, keywords, or hrefs as needed.
4. **Would a user reading today's help content be misled?** If yes, the content must be updated before the work is considered done.

## Triggers → Required Action

| Change Type | Required Action |
|-------------|-----------------|
| **New user-facing feature** | Assess whether a new article should be published. If unsure whether it warrants one, ask the user. |
| **Bug fix that changed observable behavior** | Search existing articles for the affected feature. Update wording, steps, or screenshots so they match current behavior. |
| **Feature modified** (UI copy, workflow, naming, limits) | Search BOTH articles AND any static guide entries. Update every mention. |
| **Feature removed** | Archive the related article. Remove any static guide entry. |
| **New integration** (API key, OAuth client, third-party connector) | Likely needs a new article. |
| **Pricing, billing, or limits change** | Search all pricing/billing-adjacent articles. Update numbers, tier names, currency mentions. |
| **New admin or permission model** | Likely needs a new article covering who can do what. |

## Where to Check and Update (fill in for your project)

- **Article store**: `[your articles location — DB table, markdown directory, etc.]`
- **Article admin / edit UI**: `[path or URL]`
- **Static guide entries (if any)**: `[file path]`
- **Search pattern**: `[grep target, API search endpoint, or admin search UI]`

If you have multiple stores (e.g., DB-driven articles AND a static curated guides array), they are typically NOT synced — update each independently.

## When to Ask vs. Proceed Automatically

**Proceed automatically (no need to ask):**
- Updating an existing article so UI copy in the article matches current UI copy
- Bumping a version number, date, or limit value in an existing article
- Fixing a broken link or outdated screenshot description
- Archiving content for a feature that was removed
- Updating keywords when a feature is renamed

**Ask the user:**
- Whether to publish a brand-new article (vs. leaving it as `draft`)
- Whether a new user-facing feature warrants an article at all (some internal/admin changes don't)
- Whether a new static guide entry should be created
- Whether a subtle bug fix's behavioral change is significant enough to warrant any update
- If multiple existing articles cover overlapping ground and the change prompts a rewrite/consolidation

Rule of thumb: if the change is **corrective** (bring docs in line with reality) → proceed. If the change is **generative** (create new published content) → ask.

## Decision Checklist Before Shipping

- [ ] Searched existing articles for mentions of the feature/flow being changed
- [ ] Searched static guides (if any) for matching keys / keywords / titles
- [ ] Drafted or updated articles that reference the old behavior
- [ ] Updated static guides if titles, descriptions, or hrefs changed
- [ ] Archived content for removed features
- [ ] Asked the user about any new article publication when uncertain
- [ ] **Reported the help content changes to the user** (see below)

## Always Report Help Content Changes to the User

After any work that touched — or deliberately declined to touch — help content, include a short **Help Content** section in the end-of-turn summary. The user must always know what shipped to help so they can review it.

Format:

```
Help Content:
- Created article: "<title>" (status: <draft|published>, slug: <slug>)
- Updated article: "<title>" — <one-line summary of what changed>
- Archived article: "<title>"
- Updated guide: <key> — <one-line summary>
- No help content changes: <one-line reason, e.g. "admin-only change, no user-facing surface">
```

Rules:
- Always include this section when help content was touched, even if only one article was edited.
- Always include this section when the change was user-facing but you deliberately skipped help updates — state the reason so the user can override.
- Omit only when the change has no plausible user-facing impact (e.g., refactor, internal tooling, test-only change).
- List each article/guide individually — don't summarize as "updated several articles."
- Include the slug or file path so the user can jump straight to the content.

## Anti-Patterns (Never Do)

- Shipping a feature without checking help content
- Changing UI copy without updating the article that quotes the old copy
- Assuming "someone else will update the docs"
- Creating a new article without confirming with the user whether to publish or keep as draft
- Treating help content maintenance as optional or a follow-up task

## Why This Matters

Users trust help content to match the product. When it drifts, they:
1. Follow outdated steps, get lost, file support tickets
2. Lose confidence in the product
3. Find any AI assistant (which often grounds answers in help content) less accurate

Keeping help in sync is part of shipping — not a separate chore.
