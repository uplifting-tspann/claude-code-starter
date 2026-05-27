# claude/rules/

Rules loaded automatically into Claude Code's context. Each rule is a markdown
file with optional frontmatter (path scopes, applies-to). When the user is in
a matching directory, the rule is included in the system prompt.

## What's here (v0.1)

| Rule | What it does | Polish status |
|------|--------------|---------------|
| `proof-of-work.md` | Mandates a `Proof of Work:` section at the end of any turn that modified files. Backed by the Stop hook in `claude/hooks/proof-stop-hook.sh`. | Light scrub pending (mentions "Tommy") |
| `whats-next.md` | Mandates a `What's Next:` section as the final block of every response. Mode A (options) for decisions, Mode B (instructions) for clear actions. | Light scrub pending |
| `commit-discipline.md` | Don't auto-commit. Wait for explicit authorization. Bundle related changes. | Medium scrub pending (mentions Cloud Build, hub-backend) |
| `no-glazing.md` | Anti-sycophancy. No "great question" openers. Disagree in the first sentence. | Light scrub pending |
| `dates-and-times.md` | Local-time convention. Forbid `new Date('YYYY-MM-DD')` and `datetime.utcnow()`. | Mostly portable |
| `wcag-aa-contrast.md` | Color/contrast floor at WCAG AA. Includes safe-token table. | Mostly portable |
| `verify-db-objects.md` | Verify function/enum/column names against live DB before writing SQL. | Mostly portable |
| `e2e-test-evolution.md` | E2E test suite must evolve with every feature/fix. | Medium scrub pending (mentions Docs/GCP path) |
| `help-article-evolution.md` | Help articles must evolve with features. | Medium scrub pending (mentions Uplift Help) |
| `changelog-evolution.md` | Customer-facing changelog must evolve with shipped work. | Medium scrub pending (mentions Bridge, `/whats-new`) |

## What's missing (intentionally)

The source `~/.claude/rules/` directory has ~10 more rules that are too
project-specific to ship in a public template:

- `backend-conventions.md`, `frontend-conventions.md`, `database.md`,
  `deployment.md`, `testing.md`, `security.md`, `pricing-and-currency.md`,
  `metrics-batching.md`, `auto-test-review.md`
- `project-overview.md` and `messaging-brief.md` (need to be generalized into
  templates with placeholders — coming in a follow-up pass)

If you want the *shape* of those rules (e.g., "what should my project's
backend-conventions rule cover?"), `WHY.md` will document the categories
when it lands.

## How rules get loaded

Claude Code loads any markdown file in `~/.claude/rules/` into the system
prompt. Optional frontmatter can scope a rule to specific paths:

```markdown
---
applies-to: ["~/projects/my-app/**"]
---

# My App-Specific Rule
...
```

No frontmatter means "load globally." Most rules in this starter are global.

## Adding your own rules

Drop a `.md` file in this directory. Keep each rule:

- **One topic per file.** Don't conflate "commits" and "PRs" — separate rules.
- **Short and scannable.** Rules compete for context budget.
- **Lead with the rule itself**, then `**Why:**` and `**How to apply:**` lines.
- **Cite a real incident** when you can — it helps future-you remember the
  reason behind the rule.
