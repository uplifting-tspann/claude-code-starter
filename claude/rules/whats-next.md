# What's Next — Mandatory End-of-Turn Closer

## Core Rule

Every completed task MUST end with a **What's Next** section as the final
block of the response. No exceptions. This is the closer — it goes after
`Proof of Work:`, `Changelog:`, `Help Content:`, and any other mandated
end-of-turn sections.

The point: the user should never have to guess what comes next or whether
the workstream is alive or done. Each turn ends with either a decision
they need to make, an action they or Claude should take, or an explicit
"this workstream is done."

## Required Format

```
What's Next:
1. <item>
2. <item>
3. <item>
```

Always numbered. Always under the literal heading `What's Next:` (with
the colon, capital W, capital N, smart-apostrophe-free).

## Two Modes

### Mode A — Seeking the user's input

When the next step depends on a choice the user needs to make, **label each
option with a capital letter** (A, B, C, D). Lead with the recommended
option when there is one, and mark it `(recommended)`.

```
What's Next:
1. A) Ship to staging now and verify with the demo data (recommended) — fastest path; rollback is one revert
   B) Add the regression test first, then ship — slower but closes the gap that caused the original bug
   C) Hold for tomorrow's review — only if you want a second pair of eyes on the migration shape
```

Rules for option mode:
- 2-4 options max. More than that means you haven't narrowed it enough.
- Each option is a coherent alternative, not a sub-step of the same path.
- Name the trade-off in one short clause after the em-dash.
- If one option is clearly better, mark it `(recommended)` and put it first.
- Don't manufacture options to seem balanced. If there's really only one
  reasonable path, use Mode B.

### Mode B — Not seeking input

When the next step is a clear action (the user's, Claude's, or a wait
state), give a direct instruction or recommendation. No A/B/C labels.

```
What's Next:
1. You: manually test the new flow on staging (use the "Standard" template)
2. If green, authorize the commit so I can push to staging
3. I'll create the post-deploy reminder once staging deploy lands
```

Rules for instruction mode:
- Lead each item with the actor when relevant (`You:`, `I'll`, or
  imperative form).
- Order items by what needs to happen first.
- Be specific — "manually test on staging" is weak; name the page, the
  flow, and the expected outcome.
- If the next step is waiting (CI, deploy, customer reply), say so
  explicitly: `Wait for CI to deploy the staging service
  (~6 min) — I'll re-check status when you ping me.`

## The "Done" Closer

When the workstream is genuinely complete and nothing follow-up is
warranted, close it explicitly:

```
What's Next:
1. Close this workstream — we're done.
```

Use this when:
- The feature shipped, was verified, and no obvious follow-up exists
- A bug was fixed end-to-end (code + test + Help content + changelog
  candidate flagged)
- A research/exploration turn answered the question fully

Don't pad the list with imagined next steps just to avoid saying done.
A clean "we're done" is a feature, not a deficiency.

## Combining Modes

A single What's Next block can mix instructions and an option block
when there's a sequence of clear actions followed by a decision point:

```
What's Next:
1. I'll commit the migration + route change once you authorize (instruction)
2. Then you'll need to choose how to backfill existing rows:
   A) Run the backfill script now on prod (recommended) — 200 rows, ~30 sec
   B) Defer to the next migration window — safer but leaves rows in mixed state
   C) Skip backfill entirely — fine if downstream code tolerates NULL
3. Whichever you pick, I'll handle the run and post-verify (instruction)
```

Keep this restrained — don't nest options unless the decision is
materially blocking the rest of the work.

## Interaction with Other Mandatory Sections

Order of end-of-turn sections when multiple apply:

1. `Proof of Work:` (or `Proof of Work: trivial — <reason>`)
2. `Changelog:` (always when files modified, if your project publishes one)
3. `Help Content:` (when applicable, if your project has a help system)
4. **`What's Next:`** (ALWAYS, as the final block)

What's Next is the closer. Nothing follows it.

## When to Omit

The only time `What's Next:` can be skipped:
- Pure read-only exploration turns where the user asked a one-shot
  question and the answer is the response (e.g., "what does this regex
  match?" — answer, done, no closer needed)
- Conversational turns with no task ("thanks", "got it")

In every other case — feature work, bug fix, refactor, research that
informs a decision, doc update, memory edit, plan draft — include
What's Next.

When in genuine doubt, include it. A short `What's Next: 1. Close this
workstream — we're done.` is always better than nothing.

## Anti-Patterns (Never Do)

- Ending a turn without `What's Next:` after material work
- Vague items: "test things", "review when ready", "let me know if you
  want changes" — be specific about what, where, and who
- Padding the list with filler so it looks substantive — three real
  items beats six imagined ones
- Mixing option labels (A, B) with numbered steps in the same item
  without the nested structure shown above
- Labeling options when there's really only one path — use Mode B
- Manufacturing a decision point ("Do you want me to write a test?")
  when another rule already says yes (E2E coverage, etc.) — just
  do it and put it in instructions
- Trailing prose after the What's Next block ("Hope this helps!") —
  What's Next is the last thing on screen

## Why This Rule Exists

Without a forcing function, turns trail off into ambiguity — the user has
to read between the lines or ask "so what now?" to figure out whether
they should be testing, committing, deciding, or waiting. Making the
closer mandatory and structured (with option labels when input is
needed) collapses that ambiguity.

The "we're done" closer is equally important — it gives explicit
permission to stop, which prevents the implicit drift of "should there
be more here?" at the end of finished work.
