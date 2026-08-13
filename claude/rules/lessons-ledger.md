---
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*.jsx"
  - "**/*.py"
  - "**/backend/**"
  - "**/migrations/**"
  - "**/*.sql"
---

<!-- broad-glob-ok: cross-cutting by design — a lesson can originate from any failure class -->

# Lessons Ledger — Capture the Class, Then Promote It Out of Prose

> **Applicability:** This rule assumes you have a way to run an adversarial
> review before pushing (a `/harden`-style gate) and/or a found-bug loop
> (`found-bug-never-abandoned.md`) feeding it findings. If you don't have
> either, the ledger has nothing to capture — delete this rule, or adopt it
> once you do.

## Core Rule

Every **confirmed** finding from your pre-push review gate or found-bug loop
appends one line to a ledger file (e.g. `~/.claude/lessons.jsonl`) describing
the failure **class**. Capture is mandatory and judgment-free. Promotion —
turning a recurring class into something that cannot be forgotten — happens
later, in a periodic audit pass.

```bash
~/.claude/hooks/lesson-append.sh \
  --class missing-tenant-scope-on-join \
  --repo my-app --file "backend/routes/items.py:412" \
  --rule prefer-tenant-id-scope \
  --source harden \
  --note "join to accounts omitted the tenant_id filter"
```

## The ladder

Knowledge moves **down** this ladder, never up. Prose is a waypoint, not a
destination.

| Occurrences | What it earns |
|---|---|
| 1 | a ledger line. Nothing else — one-offs are not lessons |
| 2 | a written rule (a new file in your rules directory, or a project-memory note) |
| 3 | **must** become executable: a hook, a lint, a CI gate, or a regression test |

A class that reaches 3 and is still `enforced: none` is a standing finding in
every periodic audit until a guard lands.

## Capture the class, not the bug

The `class` field is the join key for the entire system, so it names the
*repeatable mistake*, not this instance of it.

```
Bad:   "items list leaked rows across tenants" <- one bug, joins with nothing
Good:  "missing-tenant-scope-on-join"           <- a class; recurs across repos
Bad:   "AcceptInvite crashed"
Good:  "hook-below-early-return"
```

Kebab-case, reused verbatim across sessions. When in doubt, run your audit
script and reuse an existing class name rather than minting a near-duplicate
— two spellings of one class read as two 1-hit classes and never clear a
threshold.

## What gets captured

- **Yes**: every confirmed blocker from a hardening round (both the ones that
  blocked a round and the ones fixed en route to a clean pass), every bug the
  found-bug loop confirms, every CI failure whose root cause was a repeatable
  mistake rather than flake.
- **No**: nits (they never block, and logging them floods the signal), one-off
  typos, phantom findings a verifier refuted, and anything the reviewer
  *suspected* but couldn't reproduce. Confirmed-from-evidence only.

A clean round with zero blockers writes nothing. That's a clean signal, not a
gap.

## Why this rule exists

A rules corpus can grow large purely from written-but-unenforced lessons —
every rule added because someone personally noticed the same mistake twice
and said something, with nothing in the review pipeline actually capturing
findings automatically. The highest-signal lessons a review gate produces
are exactly the ones that get thrown away on a clean pass, if nothing writes
them down.

Meanwhile, only a handful of the written rules end up *enforced* by
something mechanical. The rest is prose a model has to remember, which fails
at some nonzero rate forever — while a pre-commit or pre-tool-use hook fails
at zero. And a corpus can reach a size where adding the Nth rule reliably
helps less than it costs in context.

Hence: capture automatically (removes the human bottleneck), promote on
recurrence (converts the reliable-at-some-rate into the impossible), and
prune what never fires (keeps the context budget honest).

## Anti-patterns (never do)

- Finishing a hardening round with confirmed blockers and not appending to
  the ledger.
- Logging nits or unconfirmed suspicions — it floods the thresholds.
- Minting a new class name for something an existing class already covers.
- Answering a 3rd occurrence by *rewriting the rule more emphatically*.
  Three occurrences means the prose failed; write the guard.
- Deleting a rule during an audit without asking.
