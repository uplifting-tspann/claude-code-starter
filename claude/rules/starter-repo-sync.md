---
paths:
  - "**/.claude/rules/**"
  - "**/.claude/skills/**"
  - "**/.claude/hooks/**"
---

# Starter Repo Sync — Mandatory Evaluation When the Harness Changes

> **Applicability:** This rule only applies if you keep a **second copy** of
> your Claude Code config in a repo — a fork of this starter, a team-shared
> config repo, a dotfiles repo, anything that mirrors `~/.claude/`. If your
> `~/.claude/` is the only copy that exists, delete this rule. The rest
> assumes you maintain a mirror.

## Core Principle

Your config repo is the generalized, project-agnostic mirror of the working
setup in `~/.claude/`. It is a living artifact that MUST evolve with the
harness it mirrors.

This rule does NOT require promoting a file in the same turn. Promotions are
batched via `scripts/sync-from-source.sh --interactive`, which diffs live
against the repo's template and prompts per file. This rule's job is to make
the **evaluation** mandatory and the **reporting** non-skippable, so a
portable lesson never gets buried in `~/.claude/` and forgotten.

It is the same shape as `changelog-evolution.md`: evaluate now, batch the
write later, never let the decision go unrecorded.

## Trigger

Any turn that **creates or materially edits** a file under:

- `~/.claude/rules/`
- `~/.claude/skills/`
- `~/.claude/hooks/`

"Materially" means a change to what the rule/skill/hook *does* — a new
section, a new anti-pattern, a new incident, a changed threshold, a reversed
recommendation. Typo fixes, reformatting, and link repairs are not material.

Changes to `~/.claude/CLAUDE.md`, `settings.json`, memory files, and
workstream files do NOT trigger this rule — those are personalized, and
`sync-from-source.sh` deliberately skips them.

## The Portability Test

For each created or materially-changed file, sort it into one of three
buckets:

### 🟢 Portable — promote

The lesson holds for someone on a different codebase, different stack,
different company. Nothing about it depends on your products, your infra,
your customers.

Examples in this starter: `proof-of-work`, `whats-next`, `no-glazing`,
`commit-discipline`, `reentry-capsule`, `diagnose-from-evidence`,
`dates-and-times`, `wcag-aa-contrast`, `found-bug-never-abandoned`,
`lessons-ledger`, `session-parallelism`, `new-write-path-completeness`,
`failed-read-not-authoritative`, `harden-before-push`.

### 🟡 Conditionally portable — promote with an Applicability callout

The lesson is real and general but only applies to projects with a
particular surface or stack. Ship it, but open the file with a callout so a
reader can decide in one line whether to keep or delete it:

```markdown
> **Applicability:** This rule only applies if <condition>. If <not that>,
> delete this rule. The rest assumes you do.
```

Examples in this starter: `changelog-evolution` (needs a customer-facing
changelog), `help-article-evolution` (needs a help system),
`sqlalchemy-array-params` (needs SQLAlchemy + PostgreSQL),
`test-fixture-schema-parity` (needs integration tests against a real
database built from fixture files), `deploy-order-shared-job-hazard` (needs
shared/always-running services and migrations), `overlay-viewport-safety`
(needs a frontend with floating UI layers) — and this rule itself.

### 🔴 Project-specific — do not promote

The rule is inseparable from your products, your infra, your customers, or
your org. Promoting it ships noise to everyone else who uses the repo.

Typical 🔴 rules: your backend conventions, your frontend stack, your deploy
pipeline, your product's voice and forbidden words, your permission model,
your domain-specific "this artifact must evolve with the product" rules.

**When a 🔴 rule encodes a genuinely good *pattern***, don't ship the rule —
document the pattern. `WHY.md` has a "patterns worth stealing" section for
exactly this. A one-paragraph description of the shape ("a mandatory
end-of-turn evaluation section for any living artifact that must evolve with
the product") is more useful to a stranger than your implementation of it.

### The tiebreaker

**Strip every proper noun from the file in your head. Is there still a rule
left?** If yes → 🟢 or 🟡. If the file collapses into nothing without your
product names, it's 🔴.

## Always Report a `Starter Repo:` Section

After any turn that triggers this rule, include a **Starter Repo** section
in the end-of-turn summary so the promote/skip decision is auditable.

Format:

```
Starter Repo:
- Promote (portable): <file> — <one-line reason>
- Promote (conditional): <file> — <the Applicability condition>
- Skip (project-specific): <file> — <one-line reason>
- Pattern worth documenting: <file> — <the generalizable shape, for WHY.md>
```

Rules:

- One line per created or materially-changed file. Every triggering file
  gets a line — **including the skips.** A silent skip is indistinguishable
  from an oversight.
- Name the **bucket** explicitly. "Promote" without a bucket is not a
  reviewable claim.
- For 🟡, state the Applicability condition in the same line — that's the
  thing the user is actually approving.
- Do NOT write to the config repo in the same turn. This rule is
  report-only. Promotion is a batch operation the user runs.

## How Promotion Actually Happens (the batch step)

When the user is ready — after a few rules have accumulated, or when the
repo feels stale:

```bash
cd <your-config-repo>
bash scripts/sync-from-source.sh                # read-only report
bash scripts/sync-from-source.sh --diff         # with diffs
bash scripts/sync-from-source.sh --interactive  # promote/pull per file
```

Then the promoted files must be **scrubbed to house style** before commit
(the sync script copies verbatim — it does not generalize):

- The user's name → "the user" / they-them. Never a name, never he/him.
- Product names → "your project" / "your app" / generic.
- Infra specifics (cloud project ids, service names, hostnames, database
  names, error-tracker slugs) → placeholders or config-driven, matching
  whatever convention the existing generalized files use.
- Customer names → "a customer". Always.
- **Keep the motivating incidents.** They are the most valuable part of
  every rule — a rule with a real scar is a rule people follow. Strip the
  identifying details, keep the scar. Dates may stay.
- Cross-references must resolve within the repo. A promoted rule that points
  at a 🔴 rule the repo doesn't ship is a broken reference — genericize the
  reference in prose, or drop it.

The canonical example of the scrub, if you forked this starter:

```bash
diff claude/rules/no-glazing.md ~/.claude/rules/no-glazing.md
```

After promoting, update the affected README (`claude/rules/README.md`,
`claude/skills/README.md`, `claude/hooks/README.md`) — each has a table that
must gain a row for the new file.

## The Drift Trap — refresh, don't only add

**`DIFFERS` is not noise to be skipped.** The sync script reports a promoted
file as `DIFFERS` forever, because the repo copy is scrubbed and the live
copy isn't. That is by design — but it means `DIFFERS` carries no
information about whether the *content* actually drifted, and it is easy to
start ignoring the whole `DIFFERS` list. When a 🟢/🟡 rule is materially
edited live, its repo twin is now stale in substance, not just in wording —
and the report cannot tell you which. Promoting a *new* rule while its ten
neighbors quietly rot is the failure this rule exists to prevent.

Cheap check for real drift vs. scrub noise:

```bash
diff claude/rules/<name>.md ~/.claude/rules/<name>.md | grep -c '^[<>]'
```

A handful of changed lines is the scrub. Dozens means the rule actually
moved, and the repo needs a content refresh — not just a re-scrub.

## Anti-Patterns (Never Do)

- Writing a new portable rule and never flagging it for promotion — it dies
  in `~/.claude/` and the config repo silently ages.
- Auto-writing to the config repo in the same turn as the rule change.
  Promotion is batched and reviewed; two diffs in one turn is how the
  scrubbing gets sloppy.
- Promoting a file **verbatim**. The sync script copies; it does not
  generalize. An unscrubbed promotion ships the user's name, their
  customers' names, and their infra — to a repo that may be public.
- Promoting a rule whose cross-references point at rules the repo doesn't
  ship.
- Adding a new file to `claude/rules/` or `claude/skills/` without adding
  its row to that directory's `README.md` table.
- Skipping the `Starter Repo:` section because "it's obviously not
  portable" — say `Skip (project-specific): <file> — <reason>` explicitly
  so the decision is auditable.
- Treating a 🔴 verdict as the end of the thought. Ask whether the *pattern*
  is worth a paragraph in `WHY.md` even when the rule isn't worth shipping.

## Interaction with Other Rules

- **`changelog-evolution.md`** — same shape (evaluate now, batch the write,
  always report), different artifact. Your config repo is the changelog of
  your harness.
- **`proof-of-work.md`** — `Starter Repo:` is a sibling section in the
  end-of-turn block, not a replacement for `Proof of Work:`.
- **`commit-discipline.md`** — the config repo is a separate repo under the
  same discipline: commit locally by explicit path, never auto-push, wait
  for authorization. If it's public (as this starter is), a careless push is
  visible to strangers immediately, so the push gate matters even more here.

## Turn Order

`Starter Repo:` sits with the other end-of-turn evaluation sections:

1. `Re-entry Capsule:` (top of response)
2. Response body
3. `Proof of Work:`
4. `Changelog:` (if you publish one)
5. **`Starter Repo:`** (when the harness changed)
6. `What's Next:` (always, final block)

## Why This Rule Exists

This starter repo was built to package a working setup — rules, hooks,
skills, the memory model — for people starting from scratch. It was pushed
once and then not touched for weeks, during which the live setup it mirrors
gained dozens of rules and skills, and nearly every rule it did ship had
drifted in substance. The commit-discipline rule grew an entire
auto-staging model the template knew nothing about. The what's-next rule
grew its option-block rules. The changelog rule nearly doubled.

The repo didn't rot because anyone decided to stop maintaining it. It
rotted because nothing in the loop ever *asked*. `sync-from-source.sh`
existed the whole time and was never run — a tool with no trigger is a tool
that doesn't get used.

This rule is the trigger.
