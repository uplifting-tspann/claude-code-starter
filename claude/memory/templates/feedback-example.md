---
name: feedback-no-auto-commit
description: Wait for explicit authorization before any git commit/push. Bundle related changes into one commit. Reset after a session shipped 3 small adjacent commits that should have been one.
metadata:
  type: feedback
---

After completing code changes, stop at "files modified." Report what
changed and wait for explicit authorization before running `git add`,
`git commit`, or `git push`.

**Why:** Every push to staging triggers a build + E2E suite + deploy
cycle (several minutes each). Five auto-commits = five cycles for what
should have been one bundled story. Beyond cost: the staging history
becomes a stream of micro-fixes that's harder to scan and revert. A
session on 2026-05-11 shipped three adjacent commits (copy tweak, then
logic fix, then a follow-up) that would have read better as one
bundled change with one deploy. The auto-commit policy got reset
after that.

**How to apply:** Treat completion as "files modified, awaiting your
call." Authorization phrases that flip the switch: "commit this",
"push it", "ship it", "let's deploy", "okay push it up." Ambiguous
phrases ("looks good", "thanks") are NOT authorization — ask:
"Want me to commit + push?"

Read-only git operations (`git status`, `git diff`, `git log`) don't
require authorization. Only `git add` / `git commit` / `git push`
do.

Related: [[feedback-bundle-commits]], [[feedback-no-amend]].
