# WHY.md — The Reasoning Behind This Starter

This file is the deep dive. The [README](README.md) tells you *what's
here* and *how to install it*. This tells you *why each pattern exists*,
*what failure mode it prevents*, and *when you should adopt it as-is vs.
adapt it for your own work*.

It's written for someone trying to understand the workflow well enough
to either (a) bend it to a different stack, (b) extend it with their own
rules and skills, or (c) decide that part of it doesn't fit them and
should be left out.

If you're reading this because a friend pointed you at the repo: start
here, then skim [`claude/rules/README.md`](claude/rules/README.md) to
see the rules in context.

---

## Why opinionated?

A neutral, framework-agnostic Claude Code starter ends up being just a
directory tree with no point of view. You can copy it and still not
know how to *work*. The actual value is in the **opinions** — what
conventions pay off in practice, what failure modes they prevent, what
trade-offs they accept.

So this starter takes positions. Some of them you'll disagree with.
That's fine — fork it and change them. But the opinions are the
deliverable, not the file count.

The opinions cluster around three ideas:

1. **Forcing functions beat reminders.** Claude (and you) forget rules
   over a long session. A Stop hook that blocks turn-end if a "Proof of
   Work" section is missing works; a memory bullet saying "remember to
   include proof" doesn't.
2. **Defaults should be conservative, opt-ins explicit.** No
   auto-commit. No auto-overwrite of existing config. No auto-publish
   of changelog entries. The user is always in the loop for irreversible
   moves.
3. **Reasoning should be persistent.** Decisions log the *why*, not
   just the *what*. Workstream files survive across sessions.
   Memory captures rules-of-the-game so the next session doesn't
   re-litigate them.

If those three ideas don't appeal to you, this starter probably isn't
your shape.

---

## The mental model: rules, skills, hooks

Claude Code has three knobs for shaping how Claude behaves. They're
easy to confuse. The right one for a given job depends on **when** you
want the behavior to fire and **whether** you want Claude to invoke
it or the harness to enforce it.

| Knob | What it is | Fires when | Who controls |
|------|-----------|-----------|--------------|
| **Rule** | Markdown loaded into the system prompt | Every turn in a matching directory | Claude reads it; behaves accordingly (or doesn't — see "forcing functions" below) |
| **Skill** | A procedure stored in `~/.claude/skills/<name>/SKILL.md` | When you type `/<name>` (or Claude invokes if enabled) | The user (or Claude) triggers it |
| **Hook** | A shell script wired in `~/.claude/settings.json` | On a specific tool-call event (PreToolUse, PostToolUse, Stop, etc.) | The harness; runs regardless of Claude's intent |

**Heuristic for picking:**

- "Claude should always do X / never do Y, regardless of context" →
  **rule**.
- "When I want X done, I'll type a command" → **skill**.
- "If Claude tries to do X, block it; or if Claude misses Y, force
  them to add it" → **hook**.

A rule says *what should happen*. A skill is *how to do something on
demand*. A hook is *enforcement that doesn't depend on Claude
remembering*.

### Why "forcing functions beat reminders"

Rules are loaded into the system prompt, but the system prompt is
long, and Claude (like any reader) attends more to recent context.
On a long session, a rule that says "always include a Proof of Work
section" gets followed maybe 60% of the time. That's not good enough
for something that prevents a real failure mode.

The fix is a **hook**. The Stop hook
([`claude/hooks/proof-stop-hook.sh`](claude/hooks/proof-stop-hook.sh))
reads the transcript at turn-end, checks whether Edit/Write tools
were called and whether the final message contains "Proof of Work:",
and *blocks the turn* with guidance if both conditions hold. Claude
can't forget — the harness won't let the turn end.

The lesson: when something matters enough that "Claude usually
remembers" isn't good enough, write a hook. When it doesn't, a rule
is fine.

---

## The mandatory turn sections

The rules in this starter mandate a fixed structure around any turn
that modified files. One block at the **top**, several at the
**bottom**:

```
Re-entry Capsule:     ← top of response, first thing on screen
[response body]
Proof of Work:
Changelog:            (if your project publishes one)
Help Content:         (if your project publishes it)
Config Repo:          (if you mirror your config to a repo)
What's Next:          ← always last, nothing follows it
```

Each exists because of a specific failure mode it prevents. Each is
"mandatory" in its rule, and one (`Proof of Work:`) is also enforced
by a hook.

### Re-entry Capsule — what it prevents

**The failure:** You come back to a workstream you parked three days
ago — or one of the eight you're running concurrently — and you have to
scroll back through the chat to reconstruct where you were.

That scroll-back cost is what caps how many workstreams you can run at
once. The Capsule eliminates it by making the *last message of every
chat* self-sufficient as re-entry state: workstream, goal, last action,
next move, files touched. Five lines, at the top, so it's the first
thing your eye lands on when you reopen a chat cold.

It's the bookend to `What's Next:` — the Capsule says "where am I?",
What's Next says "what do I do?" Neither requires scrolling.

The rule: [`claude/rules/reentry-capsule.md`](claude/rules/reentry-capsule.md).

### Proof of Work — what it prevents

**The failure:** Claude reports a feature "done." You go to use it.
The first thing you try is a bug.

Root cause: features get marked complete based on "the code compiles"
or "type checks pass" — not based on actually exercising the user
path. The fix is to require explicit verification: what changed, how
you verified it, what you observed, and (critically) what you *didn't*
verify.

The "Not verified:" line is the most valuable part. It surfaces gaps
you'd otherwise discover by stumbling.

The rule: [`claude/rules/proof-of-work.md`](claude/rules/proof-of-work.md).
The enforcement: [`claude/hooks/proof-stop-hook.sh`](claude/hooks/proof-stop-hook.sh).

### Changelog — what it prevents

**The failure:** Customer-visible work ships, but the public
changelog doesn't reflect it for weeks. Users stop trusting the page.
The next launch announcement lands softer than it should.

The rule doesn't require *writing* the entry in the same turn —
entries get batched. It requires *flagging the candidate* at ship
time so a periodic sweep (e.g., a `/whats-new` skill that scans `git
log`) catches everything that matters.

The rule: [`claude/rules/changelog-evolution.md`](claude/rules/changelog-evolution.md).
Conditional — delete if your project doesn't publish a changelog.

### Help Content — what it prevents

**The failure:** UI copy changes; the help article that quotes the
old copy doesn't. A user reading help today gets misled. Support
tickets follow.

The rule mandates a check — "which existing help content references
this feature?" — at ship time, plus a report block in the turn
summary so the user always knows whether help was touched.

The rule: [`claude/rules/help-article-evolution.md`](claude/rules/help-article-evolution.md).
Conditional — delete if your project doesn't publish help content.

### What's Next — what it prevents

**The failure:** A turn trails off into ambiguity. The user has to
read between the lines or ask "so what now?" to figure out whether
they should be testing, committing, deciding, or waiting.

The rule mandates a numbered list at the end of every working turn,
in one of two modes:

- **Mode A** — options labeled A, B, C, D when the next step is the
  user's decision
- **Mode B** — instructions when the next step is a clear action

There's also a "done" closer:
```
What's Next:
1. Close this workstream — we're done.
```

This is equally important. Explicit "done" prevents the implicit
drift of "should there be more here?" at the end of finished work.

The rule: [`claude/rules/whats-next.md`](claude/rules/whats-next.md).

### Config Repo — what it prevents

**The failure:** You codify a hard-won lesson as a rule, it lands in
`~/.claude/`, and the shared/template copy of your config never hears
about it. Six weeks later the repo you'd hand a new teammate is a
museum piece.

Conditional — only applies if you keep a second copy of your config in
a repo. See **The sync problem** below for the full story, including
how this exact repo rotted.

The rule: [`claude/rules/starter-repo-sync.md`](claude/rules/starter-repo-sync.md).

### Why this specific order

Re-entry Capsule goes at the very top because its whole job is to be
the first thing you see when you reopen a chat cold. If it's buried
below a narrative lead-in, it has failed at the only thing it does.

Then the body, then the bottom stack:

Proof of Work goes first among the closers because it's the
load-bearing one — it proves the rest of the turn was real. Changelog,
Help Content, and Config Repo are side-effect concerns: "in addition to
verifying the work, did we update the surfaces that must evolve with
it?" Each one is a living artifact with no compiler to enforce it (see
**Patterns worth stealing**, below).

What's Next goes last because it's the closer — you read it and
immediately know what to do or decide. Nothing should follow it.

The common thread across all of them: **each requires an explicit answer
even when the answer is "not applicable."** A forced "not applicable —
here's why" is auditable. A silent skip is indistinguishable from an
oversight, which is the whole failure mode.

---

## The workstream model

Long-running work (something that spans more than a session, has
sub-decisions, or involves stakeholder coordination) gets its own
**workstream** — a directory under `.claude/memory/<workstream-name>/`
with three files:

| File | What it captures | Mutability |
|------|------------------|------------|
| `state.md` | Where we are right now — current phase, active tasks, blockers, next-session focus | Overwrite in place |
| `decisions.md` | Append-only log of material decisions with *why* | Never edit past entries |
| `open_questions.md` | Tracker for unresolved decisions (Q1, Q2, …) | Edit status; never delete |

The template lives in
[`project-template/workstream-template/`](project-template/workstream-template/).

### Why three files instead of one

A single `notes.md` doesn't work because the three concerns have
different *mutability*:

- `state.md` is your living dashboard — you want it current. Stale
  entries are noise.
- `decisions.md` is your audit trail — you want every decision
  preserved with its reasoning, even decisions you later reversed.
  Deleting entries loses the trail of how you got here.
- `open_questions.md` is your prioritization queue — you want
  resolved entries to stay (linking out to the decision that resolved
  them) so future-you can see what was considered.

Mixing all three in one file forces a constant edit-vs-append
tension and makes the audit trail unreadable.

### When to start a workstream vs. just commit

Start a workstream when:

- The work will span more than one session
- There are decisions to make along the way (architecture, scope,
  trade-offs) that future-you will want to remember
- Stakeholders or external dependencies are involved
- The shape of "done" is not obvious yet

Just commit when:

- The work is one self-contained change you'll finish today
- There are no meaningful decisions, just execution
- A commit message captures everything important

If you're not sure, lean toward starting a workstream. It's cheap
(three template files), and it pays off the first time you come
back to the work cold.

### The append-only invariant on decisions.md

The hardest part of using this model is resisting the urge to edit
past entries. A decision was made on a Tuesday based on what was
known at the time. A month later you change your mind. The
**correct** move is to add a new entry that cites the old one and
explains the reversal — not to edit the old entry to match current
thinking.

Why: the value of decisions.md is showing how reasoning *evolved*.
If you rewrite history, you lose the evolution.

---

## The memory model

Memory is persistent context that survives across sessions. It lives
in `~/.claude/projects/<project>/memory/`:

- `MEMORY.md` — one-line index, never grows past ~200 lines
- One file per topic — full content (e.g.,
  `feedback_no_auto_commit.md`, `reference_db_connection_paths.md`)

The index is loaded into every conversation. Per-topic files are
loaded when relevant (or when the user explicitly asks). Keeping the
index lean is what makes the system scale.

### The four types

When you save a memory, it gets one of four types in its frontmatter:

| Type | What it captures | Example trigger |
|------|------------------|-----------------|
| **user** | Who the user is, their role, what they know | "I'm a data scientist" → save user role |
| **feedback** | How the user wants work done, what to avoid, what worked | "Don't auto-commit" → save the rule + why |
| **project** | Active work state, deadlines, who's doing what | "We're freezing merges Thursday" → save with date |
| **reference** | Pointers to external systems (where to find X) | "Bugs tracked in Linear project FOO" → save the location |

### What NOT to save

- Code patterns, file paths, conventions — these can be derived by
  reading the project state. Memory shouldn't duplicate the
  codebase.
- Git history — `git log` is authoritative.
- Debugging solutions — the fix is in the code; the commit message has
  the context.
- Ephemeral task details — in-progress work belongs in workstream
  files or todos, not memory.

### The stale memory problem

Memory captures what was true at a point in time. A function name in
memory may have been renamed; a Linear project may have been archived;
a "Tuesday merge freeze" may now be in the past.

The rule of thumb: **before acting on a memory, verify it's still
correct**. If a memory says "the X function lives in `services/foo.py`",
grep before you cite it. If it says "the user prefers approach Y",
check recent conversations for signals it's still true.

When a memory turns out to be stale, *update or delete it* — don't act
on it.

---

## Commit discipline

The rule at
[`claude/rules/commit-discipline.md`](claude/rules/commit-discipline.md)
says: after completing code changes, stop at "files modified." Don't
`git add`, `git commit`, or `git push` unless explicitly told to.

This surprises people. Most assistants are eager to wrap up — they
auto-stage, auto-commit, auto-push. That seems helpful. So why ban it?

### Why no auto-commit

Three reasons:

1. **Every push has a cost.** Pushing to an integration branch
   typically triggers CI (minutes), E2E tests (more minutes), and
   deploy steps. Five auto-commits = five build-and-deploy cycles for
   what should have been one bundled story.

2. **Commit history is for humans, not the assistant.** A clean
   history makes reverts safe and PR review fast. Splitting one
   coherent change into "fix copy", "fix logic", "fix the test" makes
   the history less scannable, not more.

3. **The user holds the deploy decision.** Even when the code is
   right, the *timing* of a push is sometimes wrong — there's a freeze,
   another change in flight, or coordination needed. The assistant
   shouldn't make that call.

### Why bash is allowed but git isn't

The rule only blocks `git add` / `git commit` / `git push`. Everything
else — `git status`, `git diff`, `git log`, running tests, starting
the dev server, querying the DB — is fine without authorization.

Why this cut: read-only and local operations are recoverable. State
that escapes to a remote (a commit, a push, a PR comment) is not. The
authorization gate matches the blast radius.

### What "explicit authorization" looks like

These phrases are green lights:
- "commit this" / "push it" / "ship it"
- "let's deploy" / "send to staging"
- Any unambiguous "yes please commit" in response to an offer.

These are NOT green lights:
- "looks good" (could mean "the code looks good", not "commit it")
- "thanks" (gratitude, not authorization)
- Silence after you offered to commit

When in doubt, ask: *"Want me to commit + push?"* It costs one round
trip; it prevents one wrong push.

---

## How to evolve the system

This starter isn't a thing you install once and forget. It evolves
with your work — new failure modes show up, new patterns get codified
as rules, old rules get refined or retired.

### Adding a new rule

When you find yourself correcting Claude the same way three times,
that's a rule waiting to be written. Drop a markdown file in
`~/.claude/rules/`:

1. **Lead with the rule itself.** One sentence at the top: "Do X. Never
   do Y."
2. **Then explain *why*.** A `**Why:**` line citing what failure mode
   this prevents — ideally a real incident.
3. **Then explain *how to apply*.** A `**How to apply:**` line saying
   when/where the rule kicks in.
4. **Cite a real example.** Future-you (and Claude) will trust the
   rule more if you can see why it exists.

Keep each rule one-topic, scannable, and under a few hundred lines.
Rules compete for context budget.

### Adding a new skill

When you find yourself manually doing the same procedure a few times,
that's a skill waiting to be written. Create a directory under
`~/.claude/skills/<name>/` with a `SKILL.md` inside:

```yaml
---
name: my-skill
description: One-line description (shown in skill picker)
disable-model-invocation: true   # optional — prevents Claude from auto-running
---

# my-skill

[Procedure here. Numbered steps, explicit confirmations before
destructive moves.]
```

Skills are recipes, not rules. If the answer is "Claude should always
do X regardless of being asked," that's a rule. If it's "do X when I
ask for it," that's a skill.

### Adding a new hook

When a rule isn't being followed consistently and the cost of forgetting
is high, write a hook. Drop a shell script in `~/.claude/hooks/`,
wire it in `~/.claude/settings.json` under the right event
(`PreToolUse`, `PostToolUse`, `Stop`, etc.).

Hook contracts:
- Exit 0 → allow the action
- Exit 2 → block, with stderr shown to Claude
- Input is JSON on stdin (`tool_input.file_path`, `tool_input.command`,
  `transcript_path`, depending on event)
- Keep them fast. Timeout is configured in the wiring; over ~1s is
  noticeable.

See [`claude/hooks/proof-stop-hook.sh`](claude/hooks/proof-stop-hook.sh)
for a working example.

### The sync problem

This is the part that's hardest to get right — and the part this repo
got wrong first, in exactly the way this section predicted.

Once you've installed `~/.claude/` from this template, your local config
and the template start diverging. You edit a rule. You add a skill. You
tweak a hook. Some of those changes are *general* (the next person to
fork this would benefit); some are *project-specific* (only relevant to
your stack). Without a deliberate cadence, your local install drifts away
from the template and the template stops being a useful reference. A
friend who clones it gets the old version of everything.

Two things are needed, and they are not the same thing:

**1. A tool.** [`scripts/sync-from-source.sh`](scripts/sync-from-source.sh)
walks `rules/`, `skills/`, and `hooks/`, diffs live against template, and
categorizes every file as `IDENTICAL` / `DIFFERS` / `LIVE ONLY` /
`TEMPLATE ONLY`. Run it read-only for a report, `--diff` to see what
changed, or `--interactive` to promote (live → template) and pull
(template → live) per file. It deliberately skips `CLAUDE.md`,
`settings.json`, and `projects-config.json` — those are personalized and
don't sync.

**2. A trigger.** The tool existed for seven weeks and was never run once.
In that window the live setup this repo mirrors gained 23 rules and 10
skills, and *every one* of the ten rules the template did ship drifted in
substance — commit-discipline grew an entire auto-staging model the
template knew nothing about.

The repo didn't rot because anyone decided to stop maintaining it. It
rotted because nothing in the loop ever *asked*. **A tool with no trigger
is a tool that doesn't get used** — which is the same lesson as "forcing
functions beat reminders," applied to the harness itself.

So the trigger is a rule:
[`claude/rules/starter-repo-sync.md`](claude/rules/starter-repo-sync.md).
Any turn that materially changes a file in `~/.claude/{rules,skills,hooks}`
must emit a `Config Repo:` section sorting each changed file into one of
three buckets:

- 🟢 **Portable** — promote. The lesson holds on a different codebase,
  stack, and company.
- 🟡 **Conditionally portable** — promote, but open the file with an
  `> **Applicability:**` callout so a reader can decide in one line
  whether to keep or delete it.
- 🔴 **Project-specific** — don't promote. Inseparable from your products,
  infra, or customers.

The tiebreaker: **strip every proper noun from the file in your head. Is
there still a rule left?** If yes, it's 🟢 or 🟡. If the file collapses
without your product names, it's 🔴.

The rule is report-only by design. It doesn't write to the template — it
just makes the decision unskippable and auditable. The actual promotion
stays a batch operation you run and review, because the sync script
*copies verbatim* and every promoted file needs scrubbing (your name,
your product names, your customers' names, your infra) before it goes
public.

One trap worth knowing: a promoted file shows as `DIFFERS` **forever**,
because the template copy is scrubbed and the live copy isn't. That's by
design, but it means `DIFFERS` tells you nothing about whether the
*content* drifted — and it's easy to start ignoring the whole list.
Adding a new rule while its ten neighbors quietly rot is the exact
failure. `diff <template> <live> | grep -c '^[<>]'` separates scrub-noise
(a handful of lines) from real drift (dozens).

### Patterns worth stealing (that aren't shipped as rules)

Most of the rules in the live setup this repo mirrors are 🔴 — too
entangled with one company's products to ship. But several encode
*shapes* that transfer even when the rule doesn't. If you're building
your own rule set, these are the ones worth reinventing in your own
terms:

**The living-artifact evaluation.** Pick any artifact that must evolve
with the product but has no compiler enforcing it — a changelog, a help
center, a security/architecture page shown to prospects, demo data used
in sales calls, an integration catalog, a test-scenario suite. Each one
rots silently, and each rots the same way: the feature ships, nobody
*asks* whether the artifact needed updating, and six weeks later it's
lying to someone. The pattern is always identical: (a) a mandatory
question at ship time, (b) a triggers→action table so the answer isn't a
judgment call every time, (c) a required end-of-turn report section that
must be written *even when the answer is "not applicable — here's why."*
The forced not-applicable line is the load-bearing part. A silent skip is
indistinguishable from an oversight. `changelog-evolution.md` and
`help-article-evolution.md` are the two shipped here; the same skeleton
generalizes to any artifact you own.

**The fail-closed gate for autonomous action.** If your product can email
or charge *your customer's* customers with no human in the loop — a cron,
a webhook reaction, a queue drain, a "turn it on and forget it" setting —
route every such path through exactly one function, default it to OFF,
and make "do nothing and hold it as a draft" the safe posture. Put the
gate *inside* the chokepoint, not in each caller, so a future caller is
gated by default rather than by memory. Back it with a static CI audit
that red-gates the build when a new egress path appears without going
through the door. A wrongly-held action is a draft someone releases; a
wrongly-sent one charged a stranger's client without permission. The
failure modes are not symmetric, so when in doubt, gate it.

**Keep-in-sync pairs.** Any time two surfaces must carry the same fields —
a self-service settings page and its admin twin, a type declared in two
modules, a permission enumerated in both a UI and a backend check — write
the rule that names *both* paths explicitly and says "a change to one that
isn't in the other is a bug." These drift constantly and cheaply, and the
drift is invisible until a user hits the half that wasn't updated.

**Product-voice rules.** A brief with a **forbidden-word list** ("platform",
"seamless", "unlock", "revolutionize") does more to keep an LLM's copy in
your voice than any amount of positive description. Ban the words. Models
reach for them by default, and a banned-list is checkable in a way that
"write in our voice" is not.

---

## Anti-patterns

Things people do when they try to adopt this starter that *don't*
work:

### Treating rules as ceremony

If you include the "Proof of Work" section but write it as
`Proof of Work: did the thing.` you've defeated the purpose. The
section is supposed to surface what you *didn't* verify. The "Not
verified:" line is the load-bearing one. Skip it, and the section is
theater.

### Letting memory accumulate

Memory is useful because it's *curated*. If every "save this" instinct
becomes a new file with no review, the index bloats, the per-topic
files duplicate each other, and Claude loads stale context into every
conversation. Run the `consolidate-memory` skill regularly — daily if
you can, weekly minimum.

### Skipping What's Next because "nothing's blocking"

"There's nothing to decide" is rarely true. There's almost always *a*
next move — even if it's "test the change manually before pushing"
or "close this workstream — we're done." The "done" closer is also
valuable; it gives explicit permission to stop.

### Auto-committing because tests pass

Tests passing is necessary, not sufficient. The user might want to
bundle this commit with another change, push later when the freeze
lifts, or hand-review the diff first. Wait for the green light.

### Manufacturing pushback (the inverse of glazing)

The no-glazing rule says: don't open with empty agreement. The
inverse trap is: don't manufacture a counter-argument to seem rigorous.
If the user's plan is right, "looks right" + verify and move on is
the correct response. Theatrical skepticism is just as expensive as
theatrical agreement.

---

## Appendix: glossary

- **Hook** — a shell script Claude Code runs at a specific tool-call
  event. Configured in `~/.claude/settings.json`.
- **Rule** — a markdown file in `~/.claude/rules/` loaded into the
  system prompt automatically.
- **Skill** — a procedure in `~/.claude/skills/<name>/SKILL.md`,
  invoked by typing `/<name>`.
- **Workstream** — a directory under `.claude/memory/<name>/`
  containing `state.md`, `decisions.md`, and `open_questions.md` for
  long-running work.
- **Memory** — persistent context across sessions, indexed by
  `MEMORY.md` and broken into per-topic files.
- **Forcing function** — a mechanism (hook, prompt, ritual) that
  prevents a known failure mode by removing the option to skip the
  preventive step.
- **The user** — throughout this doc, "the user" = you, the human
  driving the conversation with Claude. Not "the end user of your
  product."

---

## Where to go next

- Browse [`claude/rules/`](claude/rules/) for the actual rules and how
  they're written
- Open [`claude/hooks/proof-stop-hook.sh`](claude/hooks/proof-stop-hook.sh)
  to see a working hook
- Read [`claude/skills/consolidate-memory/SKILL.md`](claude/skills/consolidate-memory/SKILL.md)
  for the shape of a skill
- Look at
  [`project-template/workstream-template/`](project-template/workstream-template/)
  for the workstream template
- If anything in here doesn't match what's actually in the repo —
  that's a bug. Open an issue or a PR.
