# Re-entry Capsule — Mandatory Top-of-Response Bookend

> **Applicability:** This rule assumes you run several concurrent Claude Code
> workstreams and regularly park one to return to it days later. If you work on
> one thing at a time and never lose your place, the Capsule is overhead — delete
> this rule. The cross-workstream status file (`PENDING.md`) described below is
> part of the same idea; keep or drop it together with the Capsule.

## Core Rule

Every coding turn that modifies files MUST open with a **Re-entry
Capsule** block as the FIRST thing in the response — above any
narrative, summary, or tool-result framing. The Capsule is the snapshot
the user reads when they reopen a chat cold; it must contain enough
state that they never have to scroll back to remember where they are.

The Capsule is the bookend at the top of the response. `What's Next:`
is the bookend at the bottom. Together they answer "where am I?" and
"what do I do?" without requiring scroll-back.

This rule exists because the user runs 5-8 simultaneous Claude Code
workstreams and is at their contextual capacity. Re-familiarizing
themselves with a parked workstream by scrolling back through chat
history is the cost that's been capping their concurrency. The Capsule
eliminates that cost.

## Required Format

```
Re-entry Capsule:
- Workstream: <slug or "ad-hoc — <2-3 word topic>">
- Goal: <one line, present tense — what we're trying to accomplish>
- Last action: <what shipped/changed/decided THIS turn — concrete, past tense>
- Next move: <what the user or Claude does next, who owns it>
- Files touched: <up to 5 paths from this turn>
```

Always exactly five bullets. Always under the literal heading
`Re-entry Capsule:` (with colon, capital R, capital C).

### Field rules

- **Workstream**: Reuse the slug the workstream is already tracked under
  (in whatever memory/index file your setup uses — e.g. a `MEMORY.md`
  listing active workstreams). For one-off work without a formal
  workstream, use `ad-hoc — <2-3 word topic>` (e.g.,
  `ad-hoc — fix login redirect`).
- **Goal**: One line, present tense. NOT "we changed X" — that's Last
  action. This is "what are we trying to accomplish across this whole
  workstream."
- **Last action**: Concrete, past tense, scoped to THIS turn. "Shipped
  migration 109 to prod" — good. "Made progress on the worker" — bad
  (vague). "Discussed approach with the user" — bad (no observable
  artifact).
- **Next move**: Specific and owned. "You: pick the scheduler interval
  (5 vs 15 min)" — good. "You: review changes" — bad (vague). "I'll
  push to staging once approved" — good. The Capsule must be
  self-sufficient — do NOT write "see What's Next" here.
- **Files touched**: Up to 5 paths from this turn. If more than 5, list
  the 5 most material and append `… +N more`. Group by repo or
  subsystem if it aids scanning.

### Trivial-turn shortcut

For trivial changes (typo, comment, dead-code removal, memory/plan file
edit, single-line config tweak):

```
Re-entry Capsule: trivial — <reason>
```

Same exemption logic as Proof of Work. If you wrote
`Proof of Work: trivial — X`, you write
`Re-entry Capsule: trivial — X` too.

## Position

**Top of response. First thing on screen.** Before any narrative,
before any "Here's what I did" framing, before any tool-result
summaries.

The reason for the strict position: when the user reopens a chat cold,
their eye lands on the most recent assistant message. If the Capsule
isn't the first thing, the position fails its purpose. They shouldn't
need to scroll within the response either.

The Capsule does NOT replace the response body. The body still
describes what happened. The Capsule is the executive summary at the
top — five lines a returning reader can use as the ENTIRE re-entry
context if they don't have time to read further.

## Trigger

Same trigger as Proof of Work: any turn that called
`Write`, `Edit`, `MultiEdit`, or `NotebookEdit`.

Pure read/exploration turns are exempt. If no file was modified, no
Capsule is required.

## PENDING.md Update Obligation

Every turn that produces a Capsule MUST also update the cross-workstream
status file — a single markdown file (e.g.
`~/.claude/workstreams/PENDING.md`) with three sections:

```markdown
# Pending
Last updated: YYYY-MM-DD

## Awaiting the user
- [<workstream-slug>] <one-line decision needed> — <relative time>

## In-flight
- [<workstream-slug>] <one-line action or wait state> — <relative time>

## Recently closed
- [<workstream-slug>] <outcome> — <relative time>
```

The point: one file to glance at to see which of N parked workstreams
need attention, instead of opening N chats to find out.

### Update rules

1. **Upsert the workstream's line** in the appropriate section based on
   the Capsule's `Next move`:
   - Next move is the user's → **Awaiting the user** section
   - Next move is Claude's, or a wait on CI/deploy/an external party →
     **In-flight** section
   - `What's Next` says "close this workstream — we're done" → move to
     **Recently closed** with the outcome
2. **One line per workstream** — not per turn. If the workstream
   already has a line, replace it. Do not accumulate history in this
   file; that belongs in the workstream's own state/notes file.
3. **Format**:
   `- [<workstream-slug>] <one-line decision/action/state> — <relative time>`
4. **Update "Last updated:"** at the top to today's date.
5. **Prune** entries older than 7 days from "Recently closed" (lazy —
   only when you happen to touch the file).

### When the workstream is `ad-hoc`

Skip the update for `ad-hoc` workstreams unless the user explicitly asks
for them to be tracked. The file is for formal, named workstreams — not
every one-off edit.

### When the user hand-resets the file

If the user says "reset PENDING" or hand-edits the file, treat that as
the new ground truth and continue from there. Don't re-add lines they
removed.

## Interaction with Other Mandatory Sections

The Capsule is the top-of-response counterpart to What's Next at the
bottom. Full order within a turn:

1. **`Re-entry Capsule:`** (top of response) — this rule
2. Response body (narrative, code summaries, tool-result framing)
3. `Proof of Work:` (or `Proof of Work: trivial — <reason>`)
4. `Changelog:` (when files modified)
5. `Help Content:` (when applicable)
6. `What's Next:` (always, as the final block)

Same exemption logic as the others: pure read/exploration turns skip
all of them (Capsule + Proof of Work + Changelog + What's Next).

## When to Omit

- Pure read/exploration turns (no Edit/Write/MultiEdit/NotebookEdit
  tool calls in the current turn) — exempt
- Conversational turns with no task ("thanks", "got it") — exempt

If files were modified, the Capsule fires. Even for memory/plan file
edits, write the trivial-form Capsule.

## Anti-Patterns (Never Do)

- **Capsule longer than 5 lines** — defeats the entire purpose. If you
  feel the urge to add a sixth bullet, you're conflating Capsule with
  Proof of Work. Five lines, no exceptions.
- **Capsule that paraphrases the response body** — the body is what
  happened in detail; the Capsule is what a returning reader needs to
  re-enter cold. If the Capsule reads like a TL;DR of the body, it's
  the wrong format. Make it stateful, not narrative.
- **`Next move: see What's Next`** — banned. The Capsule must be
  self-sufficient. The user should be able to act on the Capsule alone
  without scrolling to the bottom.
- **Vague `Last action:` like "made progress" or "discussed approach"**
  — every entry must name a concrete artifact: a commit, a file
  shipped, a migration applied, a decision recorded, an alert resolved.
  Pure-discussion turns are read-only and exempt from the Capsule
  entirely.
- **Updating the PENDING file silently without writing the Capsule** —
  the two ALWAYS fire together. The Capsule signals that cross-workstream
  state moved; the file edit is a side effect.
- **Hand-editing the PENDING file from a non-Capsule turn** — this rule
  is the only writer. Exception: the user explicitly resetting the file,
  which Claude honors.
- **Mis-categorizing in the PENDING file** — if the next move is the
  user's, it's "Awaiting the user." If it's Claude's or external, it's
  "In-flight."
- **Capsule placed below tool-result framing or below a "Here's what
  I did" lead-in** — the Capsule is the first thing in the response,
  period.

## Why This Rule Exists

The user juggles 5-8 simultaneous Claude Code workstreams and is already
at their contextual capacity — adding more would require offloading
context, and the natural offload target is the chat history itself.
The Capsule makes the last message of every chat self-sufficient as
re-entry state, so reopening a parked workstream tomorrow costs zero
scroll-back. The PENDING file does the same trick across workstreams:
one file to glance at instead of opening 8 chats to find which ones
need a decision.

This rule is the lightest possible structural intervention that unblocks
higher concurrency: ~30 tokens per turn, one maintained file, no changes
to whatever memory system or skills you already use.
