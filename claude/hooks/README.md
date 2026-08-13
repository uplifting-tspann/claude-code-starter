# claude/hooks/

Shell hooks that Claude Code runs at specific tool-call events (PreToolUse,
PostToolUse, Stop, etc.). Wired up in `~/.claude/settings.json`.

## What's here

### `proof-stop-hook.sh`

**Event:** `Stop` (when Claude is about to end its turn).

**What it does:** Checks the transcript. If Claude edited any files this turn
(`Edit`, `Write`, `MultiEdit`, `NotebookEdit`) but the final assistant message
doesn't contain `Proof of Work:`, blocks the stop and tells Claude to add the
proof section.

**Why:** Makes the [`proof-of-work` rule](../rules/proof-of-work.md)
non-skippable. Without the hook, Claude forgets the section about half the
time on long sessions.

**Failure mode it prevents:** the user testing a "completed" feature for the
first time and the *first thing they try* being a bug — because Claude
reported done without actually exercising the change.

### `pre-commit-check.sh`

**Event:** `PreToolUse` matcher `Bash` (called from settings.json on
`git commit`-shaped commands).

**What it does:** Scans the input for likely hardcoded secrets
(`password|secret|api_key|token = "..."`) and `console.log/debug` calls.
Blocks commits with possible secrets; warns (non-blocking) on console
statements.

**Why:** Cheap belt to catch the easy mistakes before they hit a remote.
Not a substitute for real secret scanning in CI.

### `guard-dangerous-bash.sh`

**Event:** `PreToolUse`, matcher `Bash`.

**⚠️ Inert until you edit it.** The script opens with a
`# CONFIG — EDIT THIS BLOCK` header holding the arrays it checks against
(`PROD_DATABASES`, `PROTECTED_BRANCHES`, `PROD_SERVICES`,
`PROD_CLOUD_PROJECTS`, and similar). It ships with `myapp_prod`-style
placeholders. Fill in your real names or the corresponding check no-ops.

**What it does:** Blocks classes of production/history accident before the
command executes, via the `{"decision":"block","reason":"..."}`
JSON-decision protocol (the reliable blocking form — not `exit 1`):

- Destructive SQL (`DROP`, `TRUNCATE`, unqualified `DELETE`) against a
  configured production database
- `gcloud run services update --set-env-vars`, which **silently deletes
  every environment variable not named in the command** (the additive
  `--update-env-vars` passes)
- Direct push to a protected branch, `--amend`/`rebase` on shared history,
  and force-push
- Deletion of a production service

**Why:** Catches the "wrong database" / "wrong branch" class of mistake —
the one where the command is perfectly valid and you meant to run it, just
not *there* or not that way. Enforcement the harness runs beats enforcement
the model has to remember.

**It is a guardrail, not a security boundary.** It pattern-matches command
strings and is trivially bypassed by anyone trying to. Its job is to catch
you on autopilot, not to stop an adversary.

Name-matching is boundary-aware, so `myapp_prod` blocks while
`myapp_prod_staging` does not.

### `lesson-append.sh`

**Event:** none — a plain CLI, invoked directly (typically from a review/
hardening flow) via `~/.claude/hooks/lesson-append.sh --class ... --repo ...
--file ...`.

**What it does:** Appends one JSON line to `~/.claude/lessons.jsonl`, the
ledger `../rules/lessons-ledger.md` describes. Concurrency-safe (one line
stays under `PIPE_BUF` so the append is atomic across sessions).

**Why:** Capture must be cheap and judgment-free, or it doesn't happen
consistently. See `lessons-ledger.md` and the `lessons-audit` skill.

### `lessons-audit-monthly.sh`

**Event:** none — scheduled externally (launchd/cron), not a Claude Code
hook event.

**⚠️ macOS + Reminders app assumed** — see the `APPLICABILITY` comment at
the top of the file for how to swap the notification step on another OS.

**What it does:** Runs the deterministic half of the `lessons-audit` skill
unattended, and only raises a reminder when something actually earned
promotion (enforcement, a recurring class despite a rule, or a malformed
ledger line). A quiet month costs nothing.

## Wiring hooks in settings.json

Example (not full file — see `settings.json.template` once it ships):

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/YOUR-USER/.claude/hooks/proof-stop-hook.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

Replace `/Users/YOUR-USER/` with the absolute path on your machine. Claude
Code's hook config doesn't expand `~`.

## Writing your own hooks

- **Exit 0** = allow the tool call (or stop) to proceed.
- **Exit 2** = block. Stderr is shown to Claude as guidance.
- **Other exits** = error; treated as block in most configurations.
- Read input from stdin as JSON. Common fields: `tool_input.file_path`,
  `tool_input.command`, `transcript_path`.
- Keep hooks fast (the timeout is in the settings.json wiring). Anything
  > 1s is noticeable.
- Test in isolation: `echo '{"tool_input":{...}}' | ./my-hook.sh`.
