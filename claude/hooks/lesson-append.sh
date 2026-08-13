#!/bin/bash
# lesson-append.sh — append one confirmed failure-class entry to the lessons ledger.
#
# The ledger is the raw dataset behind ~/.claude/rules/lessons-ledger.md.
# Capture is judgment-free and cheap on purpose: record the CLASS, not the bug.
# Promotion (rule -> enforcement) happens later, in the lessons-audit skill.
#
# Usage:
#   lesson-append.sh --class <kebab-slug> --repo <repo> --file <path:line> \
#                    [--rule <rule-or-memory-name>] \
#                    [--enforced none|test|lint|hook|ci] \
#                    [--source harden|found-bug|ci|manual] \
#                    [--note "one line"]
#
# Appends a single JSON line to ~/.claude/lessons.jsonl. Concurrent-safe: one
# line stays under PIPE_BUF so an O_APPEND write is atomic across sessions.

set -euo pipefail

LEDGER="${LESSONS_LEDGER:-$HOME/.claude/lessons.jsonl}"

CLASS="" REPO="" FILE="" RULE="" ENFORCED="none" SOURCE="manual" NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --class)    CLASS="$2"; shift 2 ;;
    --repo)     REPO="$2"; shift 2 ;;
    --file)     FILE="$2"; shift 2 ;;
    --rule)     RULE="$2"; shift 2 ;;
    --enforced) ENFORCED="$2"; shift 2 ;;
    --source)   SOURCE="$2"; shift 2 ;;
    --note)     NOTE="$2"; shift 2 ;;
    *) echo "lesson-append: unknown arg '$1'" >&2; exit 2 ;;
  esac
done

[[ -n "$CLASS" ]] || { echo "lesson-append: --class is required" >&2; exit 2; }
[[ -n "$REPO"  ]] || { echo "lesson-append: --repo is required" >&2; exit 2; }
[[ -n "$FILE"  ]] || { echo "lesson-append: --file is required" >&2; exit 2; }

# The class is the join key for the whole system — enforce one spelling.
if [[ ! "$CLASS" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "lesson-append: --class must be kebab-case (got '$CLASS')" >&2
  exit 2
fi

case "$ENFORCED" in
  none|test|lint|hook|ci) ;;
  *) echo "lesson-append: --enforced must be none|test|lint|hook|ci" >&2; exit 2 ;;
esac

case "$SOURCE" in
  harden|found-bug|ci|manual) ;;
  *) echo "lesson-append: --source must be harden|found-bug|ci|manual" >&2; exit 2 ;;
esac

LINE=$(
  CLASS="$CLASS" REPO="$REPO" FILE="$FILE" RULE="$RULE" \
  ENFORCED="$ENFORCED" SOURCE="$SOURCE" NOTE="$NOTE" \
  DATE="$(date +%Y-%m-%d)" \
  python3 -c '
import json, os
rec = {
    "date": os.environ["DATE"],
    "class": os.environ["CLASS"],
    "repo": os.environ["REPO"],
    "file": os.environ["FILE"],
    "rule": os.environ["RULE"] or None,
    "enforced": os.environ["ENFORCED"],
    "source": os.environ["SOURCE"],
}
note = os.environ["NOTE"].strip()
if note:
    rec["note"] = note[:400]
print(json.dumps(rec, separators=(",", ":")))
'
)

# Atomic-append guarantee only holds under PIPE_BUF (4096). Truncate the note
# rather than risk an interleaved half-line from a parallel session.
if (( ${#LINE} > 3500 )); then
  echo "lesson-append: entry too long (${#LINE} bytes) — shorten --note or --file" >&2
  exit 2
fi

mkdir -p "$(dirname "$LEDGER")"
printf '%s\n' "$LINE" >> "$LEDGER"
echo "ledger += $CLASS ($REPO, enforced=$ENFORCED)"
