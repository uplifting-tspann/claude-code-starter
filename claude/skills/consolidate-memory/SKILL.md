# consolidate-memory

Reads recent Claude session transcripts and updates the two persistent memory files.

## When to use

- Run automatically via the nightly `consolidate-memory` scheduled task
- Run manually when you want to capture something important from the current session: `skill: "consolidate-memory"`

---

## Instructions

### Step 1 — Load current memory files

Read both files to understand what's already captured:
- `.claude/memory/recent-memory.md`
- `.claude/memory/long-term-memory.md`

### Step 2 — Fetch recent sessions

Use `list_sessions` to get the most recent sessions (limit: 10).

Filter to sessions from the **last 24 hours** using the timestamps returned.

### Step 3 — Read each session transcript

For each session from the last 24 hours, call `read_transcript` with `limit: 30` (most recent messages) and `max_wait_seconds: 0` (don't wait for running sessions).

Skip any session that is currently running (you are in it).

### Step 4 — Extract signal

For each transcript, look for:

**Facts & decisions** — things that were decided, confirmed, or discovered:
- Architecture decisions ("we decided X", "always use Y for Z")
- Bug fixes and their root causes
- New patterns or conventions established
- External service behaviors learned (API quirks, etc.)

**Preferences expressed** — how Tommy likes things done:
- Tool choices, formatting preferences, workflow preferences
- Things Tommy corrected Claude on
- Things Tommy explicitly approved

**Active work** — what's in progress:
- Features being built and which repo/file they're in
- Known bugs being tracked
- Things blocked or waiting on something

**Things to forget** — one-off tasks that are complete and don't need to persist.

### Step 5 — Update recent-memory.md

Rewrite `recent-memory.md` with:
- Update the header timestamp and session count
- **Last 3 sessions summary** — 3–5 bullet points per session covering what was worked on and any key outcomes
- Keep the file under ~150 lines

Format:
```markdown
# Recent Memory
*Last consolidated: YYYY-MM-DD HH:MM*
*Sessions covered: N sessions from last 24hrs*

## Session: [date] — [brief topic]
- ...
- ...

## Session: [date] — [brief topic]
- ...
```

### Step 6 — Promote to long-term-memory.md

Add to `long-term-memory.md` any items that are:
- A **new preference** not already captured
- A **new decision or convention** not already captured
- An **important bug fix pattern** worth remembering
- Something Tommy explicitly said should always/never be done

Update existing entries if a preference has been refined or reversed.

Remove entries that are no longer accurate.

Keep the file organized under the existing sections:
- **Tommy's Preferences**
- **Decisions & Patterns**
- **Active Workarounds**
- **Project Notes**

Add new sections if needed (e.g., "External Services", "Recurring Issues").

### Step 7 — Report what changed

Output a brief summary:
```
Memory consolidated.
- recent-memory.md: N sessions summarized
- long-term-memory.md: N items added, N items updated, N items removed
```

---

## Rules

- **Never remove facts from long-term-memory that might still be relevant** — if unsure, keep it
- **Don't pad recent-memory** — only capture things with future value, not full conversation summaries
- **Don't store secrets, tokens, or credentials** in either file
- **One-time tasks are ephemeral** — don't capture "Tommy asked me to rename a file" unless a new pattern emerged from it
- **Prefer specific over vague** — "Always use `docs_engine` for agreement queries" beats "use the right database engine"
