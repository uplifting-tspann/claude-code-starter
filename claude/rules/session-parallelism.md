---
paths: []
---

> **Applicability:** This rule only applies if you run **multiple concurrent
> Claude Code sessions** across your projects — several terminals/worktrees
> open at once, possibly on the same branch. If you only ever run one session
> at a time, delete this rule.

# Session Parallelism — Serialize by Default, Parallelize by Exception

## Core Rule

Before starting work in a new session, check your cross-session status board
(a `ROADMAP.md`, a shared TODO, whatever tracks "what's in flight right now")
for the target repo/branch. If a workstream there is marked **in-flight**,
treat that branch as claimed — pick up that workstream instead of starting a
second one, unless the new work passes the independence test below.

Default posture: **serialize**. Finish and checkpoint one workstream before
starting the next.

## The independence test

A second concurrent session is allowed only if ALL three hold:

1. **Different repo** (e.g. `frontend` vs `backend`, not `backend` vs
   `backend`)
2. **Different branch**
3. **No shared files** — the new session's expected working set doesn't
   touch anything the first session's most recent status update lists as
   "files touched"

If any one fails, don't open a second session — queue the work instead.

## Queueing instead of fanning out

1. Check the status board for that workstream's state — "awaiting input" =
   idle, safe to resume directly; "in-flight" = another session is actively
   working it.
2. For in-flight collisions, don't start a competing session. Either wait,
   or explicitly ask whether to hand off / interrupt.

## Why this rule exists

Two sessions on the same branch, editing overlapping files, is a silent data-
loss hazard: one session's `git checkout`/`reset`/`restore` can destroy the
other's uncommitted work with no warning, and even when both commit cleanly
the merge is a worse use of time than not colliding in the first place. The
independence test exists because "different task" is not sufficient
justification for a second session when it's the same repo and branch — the
risk is in the shared working tree, not in whether the two tasks are
conceptually related.

## Anti-Patterns (Never Do)

- Opening a new session on a branch already marked in-flight without
  checking first.
- Treating "different task" as sufficient justification for a second session
  when it's the same repo and branch.
- Running a full checkpoint/save reflexively at the end of every session
  regardless of whether the workstream materially changed.
