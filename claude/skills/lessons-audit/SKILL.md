---
name: lessons-audit
description: Audit the lessons ledger (~/.claude/lessons.jsonl) and the rules/ corpus itself. Reports which classes cleared a promotion threshold, which recurred DESPITE having a rule (prose isn't working — make it executable), which rules have never fired (context tax — delete them), and whether the corpus (total lines, per-file size, path-glob breadth) is over budget. Run monthly (via a scheduled routine if you have one) or manually after a heavy hardening week or a rule-writing spree.
---

# Lessons audit

> **Applicability:** This skill assumes `lessons-ledger.md` and a
> `lesson-append.sh`-style hook are already in place, feeding
> `~/.claude/lessons.jsonl`. If you don't capture findings into a ledger,
> there's nothing here to audit — delete this skill.

The ledger is written judgment-free by your review gate and found-bug loop.
This is where the judgment happens: converting recurring classes into things
that **cannot be forgotten**, and deleting rules that earn nothing.

The premise, from `~/.claude/rules/lessons-ledger.md`: more written rules
stop helping past some point. Agents get smarter by moving knowledge
**down** the ladder (prose → executable), not by accumulating more prose.

## Step 1 — Run the deterministic pass

```bash
python3 ~/.claude/skills/lessons-audit/audit.py --window-days 90
```

Returns JSON: `needs_enforcement`, `needs_rule`, `recurred_after_rule`,
`rules_never_cited`, `entries_per_month`, `malformed_lines`, `corpus_health`.

Do not re-derive any of this by reading the ledger yourself — the script is
the source of truth for the counts.

If `malformed_lines` is non-empty, a concurrent append was clobbered.
Report it; don't silently drop the line.

## Step 2 — Act on each bucket

### `needs_enforcement` (≥3 hits, still `enforced: none`) — the main event

These have earned an executable guard. For each, pick the **cheapest
mechanism that makes the class impossible**, and propose it concretely:

| Class shape | Mechanism |
|---|---|
| Banned syntax / element / import | a `PreToolUse`/`PostToolUse`-style hook, if your harness supports one |
| Banned command form | a pre-command guard hook |
| Structural invariant across a tree | a static scan step in CI |
| Behavioral invariant | a regression test that pins it |
| Data-shape drift | a schema/parity scan |

Write the guard, prove it fires on the original failing case, then update
the ledger entries for that class to the new `enforced` value:

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home() / ".claude" / "lessons.jsonl"
rows = [json.loads(l) for l in p.read_text().splitlines() if l.strip()]
for r in rows:
    if r["class"] == "<the-class>":
        r["enforced"] = "hook"   # or test|lint|ci
p.write_text("".join(json.dumps(r, separators=(",", ":")) + "\n" for r in rows))
PY
```

A class stays in `needs_enforcement` every month until it's actually
enforced. That's deliberate — it should nag.

### `recurred_after_rule` — the highest-signal bucket

A class that kept happening *after* someone wrote a rule about it is proof
the prose isn't working. **Do not restate the rule.** Promote it to
enforcement using the table above, and note in the rule file that it's now
machine-enforced.

Skip entries where `still_unenforced` is `false` — a guard already landed
and the recurrences may predate it. Check the dates before concluding
anything.

### `needs_rule` (≥2 hits, no rule yet)

**Dedup before writing a new file — this is the actual growth valve.**
Before creating a new `rules/*.md`, grep the existing corpus for the same
topic/class first (`grep -il "<keyword>" ~/.claude/rules/*.md`). If an
existing rule already covers adjacent ground, **append a row/bullet to that
file** instead of creating a new one — a new file is the last resort, not
the default. A corpus that grows by one new file per 2nd-occurrence lesson
bloats fast; that's the pattern to break.

When a new file genuinely is warranted: write or extend a project-memory
note, or a rule file if it's a workflow/process lesson rather than a code
convention. Follow the existing memory format (frontmatter + **Why:** /
**How to apply:**). Then backfill the `rule` field on those ledger entries.

Keep it short — a large rule competes with the task for attention — and
default the `paths:` frontmatter to the **narrowest glob that actually
covers the trigger files**, not a copy-pasted broad template. That
copy-paste is exactly what produces the `broad_glob_candidates` cluster
`corpus_health` flags below. If the rule is genuinely cross-cutting by
design (fires on almost any code touch on purpose — an adversarial pre-push
gate is the canonical example), that's fine; just say so with the literal
string `broad-glob-ok` somewhere in the file's first 20 lines so the audit
doesn't re-flag it every month.

### `corpus_health` — is the rules/ corpus itself over budget?

This audits `rules/*.md` directly, not the ledger. Three signals:

- **`oversized_rules`** (>150 lines): split-to-history candidates. Move
  "why this rule exists" / incident-narrative prose into a matching
  `~/.claude/rules-history/<slug>-history.md` file (one-line pointer left
  behind) — keep the hot file to Core Rule / How to Apply / Anti-Patterns.
  Don't force a file below what its actionable content genuinely needs; a
  longer rule that's mostly trigger tables and code snippets with no
  narrative left to extract is fine as-is.
- **`broad_glob_candidates`**: rules whose `paths:` matches the corpus-wide
  catch-all glob set (near-universal — fires on nearly any source file).
  Narrow the glob to the rule's actual scope, or add `broad-glob-ok` if the
  breadth is intentional.
- **`over_budget`** (total `rules/*.md` lines > 5,000): if true, propose a
  consolidation pass in the report rather than silently continuing to add
  rules — this mirrors the `needs_enforcement` "it should nag" behavior.

`delta_since_last_run` and `history` (last 6 monthly snapshots, from
`corpus-history.jsonl`, auto-appended each run) show the trend — a corpus
that's shrinking or flat is healthy even if a few files are still
oversized; one that's climbing every month regardless of prune/split effort
is the "run a bigger consolidation pass" signal.

### `rules_never_cited` — prune

A rule no confirmed finding has ever cited is either (a) working so well
nothing violates it, or (b) dead weight. Distinguish them: if the rule is
enforced by a hook/gate, the prose is redundant with the guard — trim it to
a pointer. If it is neither cited nor enforced and predates the window by
months, propose deletion.

**Never delete a rule without asking.** Present the list with sizes and
ages and let the user decide — this bucket is a recommendation, not an
action.

## Step 3 — Report

Short and quantitative. No prose padding:

```
Lessons audit — <window>
Ledger: N entries, M classes, trend <last 3 months>

ENFORCED THIS ROUND (n)
  <class> (Nx) -> <mechanism>, guard at <file:line>, fires on <original case>

RECURRED DESPITE A RULE (n)          <- promote these
  <class> — rule <name> written <date>, N hits since

EARNED A RULE (n)
  <class> (Nx) -> wrote <memory-name>

PRUNE CANDIDATES (n) — needs your call
  <rule> (NKB, added <date>, never cited)

STILL UNENFORCED AFTER THIS ROUND (n)
  <class> (Nx) — <why not yet>

CORPUS HEALTH — <total_lines> lines / <file_count> files (budget 5,000) <OVER/under BUDGET>
  Delta since last run: <+N/-N/first run>
  Oversized (n): <rule> (<N> lines) — split-to-history candidate
  Broad-glob (n): <rule> — narrow the paths glob or mark broad-glob-ok
```

If every bucket is empty, say "ledger clean, nothing earned promotion" and
stop. Do not manufacture findings to justify the run.

## Notes

- Run monthly if you have a scheduling mechanism; otherwise run manually
  after a heavy hardening week.
- Guards written here are ordinary code changes: they follow your normal
  commit discipline (commit locally, never auto-push).
