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

**Failure mode it prevents:** Tommy testing a "completed" feature for the
first time and the *first thing he tries* being a bug — because Claude
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
