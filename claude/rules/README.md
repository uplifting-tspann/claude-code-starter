# claude/rules/

Rules loaded automatically into Claude Code's context. Each rule is a markdown
file with optional frontmatter (path scopes, applies-to). When the user is in
a matching directory, the rule is included in the system prompt.

## What's here

### Always applicable

| Rule | What it does |
|------|--------------|
| `proof-of-work.md` | Mandates a `Proof of Work:` section at the end of any turn that modified files. Backed by the Stop hook in `claude/hooks/proof-stop-hook.sh`. |
| `reentry-capsule.md` | Mandates a 5-line `Re-entry Capsule:` block at the **top** of any turn that modified files. The bookend to `whats-next` — answers "where am I?" so reopening a parked workstream costs zero scroll-back. |
| `whats-next.md` | Mandates a `What's Next:` section as the final block of every response. Mode A (options) for decisions, Mode B (instructions) for clear actions. |
| `commit-discipline.md` | Auto-stage completed work by explicit path; never auto-commit. Wait for explicit authorization. Bundle related changes. |
| `no-glazing.md` | Anti-sycophancy. No "great question" openers. Disagree in the first sentence. Includes the overshoot guard — manufactured criticism is banned too. |
| `diagnose-from-evidence.md` | Verify against primary evidence before asserting a production cause or recommending an urgent/irreversible action. The bar scales with urgency and irreversibility. |
| `dates-and-times.md` | Local-time convention. Forbid `new Date('YYYY-MM-DD')` and `datetime.utcnow()`. |
| `wcag-aa-contrast.md` | Color/contrast floor at WCAG AA. Includes the token-categorization pattern. |
| `verify-db-objects.md` | Verify function/enum/column names against the live DB before writing SQL. |
| `e2e-test-evolution.md` | The E2E suite must evolve with every feature and fix. |
| `required-env-vars.md` | Two-pattern framework for required config: the deploy config is the source of truth **and** the code fails loud in production when a var is missing. Kills the `os.getenv(X, dangerous_default)` bug class. |

### Conditional — each opens with an `> **Applicability:**` callout

Read the callout, then keep or delete the file. Don't half-apply them.

| Rule | Applies if… |
|------|-------------|
| `changelog-evolution.md` | Your project publishes a customer-facing changelog. |
| `help-article-evolution.md` | Your project publishes help/docs content users read. |
| `starter-repo-sync.md` | You keep a second copy of your Claude config in a repo — a fork of this starter, a team config repo, dotfiles — that must not rot. |
| `test-fixture-schema-parity.md` | You run integration tests against a real database built from fixture/baseline schema files rather than replayed production migrations. |
| `sqlalchemy-array-params.md` | You use SQLAlchemy `text()` against PostgreSQL. |

All rules are scrubbed of project-specific references — no company names, no
customer names, no infra identifiers. The **incidents** that motivate each rule
are kept, with identifying details stripped. A rule with a real scar is a rule
people actually follow.

## What's missing (intentionally)

The live `~/.claude/rules/` this repo mirrors has ~17 more rules that are too
project-specific to ship publicly: backend/frontend conventions, database and
deploy specifics, a product-voice brief, a permissions model, and several
domain-specific "this artifact must evolve with the product" rules.

Several of them encode *shapes* that transfer even when the rule doesn't. Those
are written up in [`WHY.md`](../../WHY.md) under **"Patterns worth stealing
(that aren't shipped as rules)"** — the living-artifact evaluation, the
fail-closed gate for autonomous action, keep-in-sync pairs, and forbidden-word
product-voice rules. If you want the *shape* of a rule this starter doesn't
ship, start there.

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

## Keeping this directory in sync with your live install

Once installed, `~/.claude/rules/` and this directory drift. Some of your edits
are general (worth promoting back here); most are project-specific (leave them
local).

- [`scripts/sync-from-source.sh`](../../scripts/sync-from-source.sh) is the
  **tool** — it diffs both sides and promotes/pulls per file.
- `starter-repo-sync.md` is the **trigger** — it makes the promote/skip
  decision mandatory and reportable whenever you change a rule, so the tool
  actually gets run.

You need both. This repo sat untouched for seven weeks with the sync script
already written, because nothing in the loop ever asked. A tool with no trigger
is a tool that doesn't get used.

One trap: a promoted rule shows as `DIFFERS` **forever** (the template copy is
scrubbed, the live copy isn't), so `DIFFERS` alone tells you nothing about
whether the *content* drifted. Use
`diff <template> <live> | grep -c '^[<>]'` to separate scrub-noise (a handful
of lines) from real drift (dozens).

## Adding your own rules

Drop a `.md` file in this directory. Keep each rule:

- **One topic per file.** Don't conflate "commits" and "PRs" — separate rules.
- **Short and scannable.** Rules compete for context budget.
- **Lead with the rule itself**, then the *why* and *how to apply*.
- **Cite a real incident** when you can — it's what makes the rule stick.
- **Add an anti-patterns section.** "Never do X" is more enforceable than
  "prefer Y."
