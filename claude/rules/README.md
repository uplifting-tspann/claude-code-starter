# claude/rules/

Rules loaded automatically into Claude Code's context. Each rule is a markdown
file with optional frontmatter (path scopes, applies-to). When the user is in
a matching directory, the rule is included in the system prompt.

## What's here

| Rule | What it does |
|------|--------------|
| `proof-of-work.md` | Mandates a `Proof of Work:` section at the end of any turn that modified files. Backed by the Stop hook in `claude/hooks/proof-stop-hook.sh`. |
| `whats-next.md` | Mandates a `What's Next:` section as the final block of every response. Mode A (options) for decisions, Mode B (instructions) for clear actions. |
| `commit-discipline.md` | Don't auto-commit. Wait for explicit authorization. Bundle related changes. |
| `no-glazing.md` | Anti-sycophancy. No "great question" openers. Disagree in the first sentence. |
| `dates-and-times.md` | Local-time convention. Forbid `new Date('YYYY-MM-DD')` and `datetime.utcnow()`. |
| `wcag-aa-contrast.md` | Color/contrast floor at WCAG AA. Includes token-categorization pattern. |
| `verify-db-objects.md` | Verify function/enum/column names against live DB before writing SQL. |
| `e2e-test-evolution.md` | E2E test suite must evolve with every feature/fix. |
| `help-article-evolution.md` | Help articles must evolve with features. Applies if your project publishes help content. |
| `changelog-evolution.md` | Customer-facing changelog must evolve with shipped work. Applies if your project publishes a changelog. |

All rules have been scrubbed to remove project-specific references. The `help-article-evolution` and `changelog-evolution` rules are conditional — they include a top-of-file "Applicability" callout saying "delete this rule if your project doesn't have a help system / changelog."

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

## Adapting these rules to your project

- **Most rules are ready as-is.** The 10 in this directory are the
  always-applicable subset of a working setup, written in project-agnostic
  voice.
- **Two are conditional.** `help-article-evolution.md` and
  `changelog-evolution.md` each open with an "Applicability" note. If your
  project doesn't publish help content or a changelog, delete the file from
  `~/.claude/rules/` — don't try to file-half-apply it.
- **You'll want project-specific rules.** This template doesn't include rules
  for *your* backend conventions, frontend stack, deploy pipeline, or
  product voice. Add them next to these. `WHY.md` (coming) will document the
  categories worth covering.

## Adding your own rules

Drop a `.md` file in this directory. Keep each rule:

- **One topic per file.** Don't conflate "commits" and "PRs" — separate rules.
- **Short and scannable.** Rules compete for context budget.
- **Lead with the rule itself**, then `**Why:**` and `**How to apply:**` lines.
- **Cite a real incident** when you can — it helps future-you remember the
  reason behind the rule.
