#!/bin/bash
# proof-stop-hook.sh — enforces "Proof of Work:" in final message when files were edited.
#
# Stdin (JSON):  {"transcript_path":"...", "stop_hook_active":bool, ...}
# Exit 0  = allow stop
# Exit 2  = block stop, stderr shown to model
#
# Logic:
#   1. If we're already in a stop-hook loop, never block (prevents infinite loop).
#   2. If no Edit/Write/MultiEdit/NotebookEdit tool calls happened AFTER the most
#      recent user message, allow (read-only or Q&A turn).
#   3. Otherwise check the last assistant message text. If it contains
#      "Proof of Work:" (case-insensitive), allow. Otherwise block with guidance.

set -u

INPUT=$(cat)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
STOP_ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

# Already in stop loop — never block again
[ "$STOP_ACTIVE" = "true" ] && exit 0

# No transcript — nothing to check
[ -z "$TRANSCRIPT" ] && exit 0
[ ! -f "$TRANSCRIPT" ] && exit 0

# Detect Edit/Write tool calls after the most recent user message.
# Transcript is JSONL; jq -s slurps to a single array.
EDITED=$(jq -s '
  . as $a |
  ([$a | to_entries[] | select(.value.type == "user") | .key] | last // -1) as $idx |
  [ $a[($idx + 1):][] |
    select(.type == "assistant") |
    .message.content[]? |
    select(.type == "tool_use" and (
      .name == "Edit" or .name == "Write" or
      .name == "MultiEdit" or .name == "NotebookEdit"
    ))
  ] | length
' "$TRANSCRIPT" 2>/dev/null)

[ -z "$EDITED" ] && EDITED=0
[ "$EDITED" -eq 0 ] 2>/dev/null && exit 0

# Get text of the last assistant message
LAST_TEXT=$(jq -rs '
  [.[] | select(.type == "assistant")] | last |
  if . == null then ""
  else
    (.message.content // []) |
    if type == "array" then
      [ .[] | select(.type == "text") | .text ] | join("\n")
    else
      tostring
    end
  end
' "$TRANSCRIPT" 2>/dev/null)

# If "Proof of Work:" is present anywhere in the last assistant message, allow
if printf '%s' "$LAST_TEXT" | grep -qi "Proof of Work:"; then
  exit 0
fi

# Block — proof missing
cat >&2 <<'EOF'
This turn modified files but the final message lacks a "Proof of Work:" section.

Add it before ending. Required format:

  Proof of Work:
  - What changed: <one-line>
  - How I verified: <specific steps — pages visited, curls run, tests run>
  - What I observed: <specific outcomes — test names, DB rows, response shapes>
  - Not verified: <gaps and why — or "none">

For trivial changes (typo, comment, dead-code, memory/plan file):
  Proof of Work: trivial — <reason>

See ~/.claude/rules/proof-of-work.md. Invoke /proof for the structured protocol.
EOF
exit 2
