# Help Articles — Mandatory Evolution Rule

## Core Principle

Help Answers (database-driven) and Help Guides (static code) are living artifacts that MUST evolve with every feature addition, bug fix, or behavioral change. This is automatic — not reminder-dependent. Help content drift is a bug.

## After Every Feature, Bug Fix, or Behavioral Change

Before considering any work complete, answer these questions:

1. **Does a new Answer need to exist?** If this change introduces a user-facing concept, workflow, or capability not already documented — draft a new Answer. If unsure, **ask the user**.
2. **Which existing Answers mention this feature?** Search by slug, title, or keyword in the `answers` table. Update any that reference the old behavior, copy, or UI.
3. **Which existing Guides point to this feature?** Check `Help/frontend/src/data/guides.ts`. Update titles, descriptions, keywords, or href as needed.
4. **Would a user reading today's Help content be misled?** If yes, the content must be updated before the work is considered done.

## Triggers → Required Action

| Change Type | Required Action |
|-------------|-----------------|
| **New user-facing feature** | Assess whether a new Answer should be published. If unsure whether it warrants one, ask the user. Also evaluate whether a Guides entry should exist. |
| **Bug fix that changed observable behavior** | Search existing Answers for the affected feature. Update wording, steps, or screenshots so they match current behavior. |
| **Feature modified** (UI copy, workflow, naming, limits) | Search BOTH Answers AND Guides. Update every mention. |
| **Feature removed** | Archive the related Answer (status = `archived`). Remove the entry from `guides.ts`. |
| **New integration** (MCP tool, API key, Zapier, OAuth client) | Likely needs a new Answer AND a new Guides entry. |
| **Pricing, billing, or limits change** | Search all pricing/billing-adjacent Answers. Update numbers, tier names, currency mentions. |
| **New admin or permission model** | Likely needs a new Answer covering who can do what. |

## Where to Check and Update

**Answers — Database-driven**
- Table: `answers` (Help DB)
- Admin UI: [Help/frontend/src/pages/admin/AnswerEditor.tsx](Help/frontend/src/pages/admin/AnswerEditor.tsx) and [Help/frontend/src/pages/admin/Answers.tsx](Help/frontend/src/pages/admin/Answers.tsx)
- Backend routes: [Help/backend/routes/help_admin.py](Help/backend/routes/help_admin.py) (create/update), [Help/backend/routes/help_public.py](Help/backend/routes/help_public.py) (search)
- Search pattern: `GET /api/answers?category=<slug>&status=published` or query the `answers` table directly by title/slug/keywords

**Guides — Static code (NOT database-driven)**
- File: [Help/frontend/src/data/guides.ts](Help/frontend/src/data/guides.ts)
- Edit the TypeScript array directly — there is no admin UI
- Each guide has: `key`, `kind`, `title`, `description`, `category`, `status`, `href`, `keywords`

**IMPORTANT:** Answers and Guides are not synced. Update them independently.

## When to Ask vs. Proceed Automatically

**Proceed automatically (no need to ask):**
- Updating an existing Answer so UI copy in the article matches current UI copy
- Bumping a version number, date, or limit value in an existing Answer
- Fixing a broken link or outdated screenshot description
- Archiving a Guide entry for a feature that was removed
- Updating keywords in `guides.ts` when a feature is renamed

**Ask the user:**
- Whether to publish a brand-new Answer (vs. leaving it as `draft`)
- Whether a new user-facing feature warrants an Answer at all (some internal/admin changes don't)
- Whether a new Guides entry should be created
- Whether a subtle bug fix's behavioral change is significant enough to warrant any Answer update
- If multiple existing Answers cover overlapping ground and the change prompts a rewrite/consolidation

Rule of thumb: if the change is **corrective** (bring docs in line with reality) → proceed. If the change is **generative** (create new published content) → ask.

## Decision Checklist Before Shipping

- [ ] Searched existing Answers for mentions of the feature/flow being changed
- [ ] Searched `guides.ts` for matching `key` / `keywords` / `title`
- [ ] Drafted or updated Answers that reference the old behavior
- [ ] Updated `guides.ts` if titles, descriptions, or hrefs changed
- [ ] Archived content for removed features
- [ ] Asked the user about any new Answer publication when uncertain
- [ ] **Reported the Help content changes to the user** (see below)

## Always Report Help Content Changes to the User

After any work that touched — or deliberately declined to touch — Help content, include a short **Help Content** section in the end-of-turn summary. The user must always know what shipped to Help so they can review it.

Format:

```
Help Content:
- Created Answer: "<title>" (status: <draft|published>, slug: <slug>)
- Updated Answer: "<title>" — <one-line summary of what changed>
- Archived Answer: "<title>"
- Updated Guides: <key> — <one-line summary>
- No Help content changes: <one-line reason, e.g. "admin-only change, no user-facing surface">
```

Rules:
- Always include this section when Help content was touched, even if only one Answer was edited.
- Always include this section when the change was user-facing but you deliberately skipped Help updates — state the reason so the user can override.
- Omit only when the change has no plausible user-facing impact (e.g., refactor, internal tooling, test-only change).
- List each Answer/Guide individually — don't summarize as "updated several articles."
- Include the slug or file path so the user can jump straight to the content.

## Anti-Patterns (Never Do)

- Shipping a feature without checking Help content
- Changing UI copy without updating the Answer that quotes the old copy
- Assuming "someone else will update the docs"
- Creating a new Answer without confirming with the user whether to publish or keep as draft
- Treating Help content maintenance as optional or a follow-up task

## Why This Matters

Users trust Help content to match the product. When it drifts, they:
1. Follow outdated steps, get lost, file support tickets
2. Lose confidence in the platform
3. Find the AI assistant (which grounds answers in Help content) less accurate

Keeping Help in sync is part of shipping — not a separate chore.
