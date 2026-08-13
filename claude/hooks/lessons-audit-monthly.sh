#!/bin/bash
# lessons-audit-monthly.sh — unattended monthly pass over the lessons ledger.
#
# APPLICABILITY: this script assumes (a) macOS with the Reminders app and
# `osascript`, and (b) you've adopted lessons-ledger.md's ledger pattern. On
# another OS, swap the osascript block at the bottom for your own
# notification mechanism (a Slack webhook, an email, a GitHub issue) — the
# audit + summarize logic above it is portable. If you don't run a ledger,
# delete this hook.
#
# Runs the DETERMINISTIC half of the lessons-audit skill (audit.py) with no
# model in the loop, writes the report, and only raises a reminder when
# something actually earned promotion. A quiet month costs nothing; a loud
# month gets a reminder telling you to run the audit and write the guards.
#
# Schedule it with launchd (macOS), cron, or your CI scheduler's equivalent.
# Runs locally by necessity if your ledger/rules/memories live only in
# ~/.claude, which is typically not a git repo any cloud routine can see.

set -uo pipefail

CLAUDE_DIR="$HOME/.claude"
AUDIT="$CLAUDE_DIR/skills/lessons-audit/audit.py"
OUT="$CLAUDE_DIR/lessons-audit-latest.json"
LOG="$CLAUDE_DIR/lessons-audit.log"

# Which Reminders list to use (macOS only). Change to match your setup.
REMINDER_LIST="Reminders"

stamp() { date '+%Y-%m-%d %H:%M:%S'; }

if ! /usr/bin/python3 "$AUDIT" --window-days 90 > "$OUT.tmp" 2>>"$LOG"; then
  echo "$(stamp) FAILED — audit.py errored, see above" >> "$LOG"
  exit 1
fi
mv "$OUT.tmp" "$OUT"

SUMMARY=$(/usr/bin/python3 - "$OUT" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))

# Only unenforced recurrences are actionable — an already-guarded class may just
# have hits predating its guard.
recurred = [e for e in d["recurred_after_rule"] if e.get("still_unenforced")]
enforce, rule = d["needs_enforcement"], d["needs_rule"]
actionable = len(enforce) + len(rule) + len(recurred)

lines = [
    f"entries={d['total_entries']} classes={d['distinct_classes']} "
    f"(window: {d['entries_in_window']})",
    f"needs_enforcement={len(enforce)} recurred_despite_rule={len(recurred)} "
    f"needs_rule={len(rule)} never_cited_rules={len(d['rules_never_cited'])}",
]
for e in enforce:
    lines.append(f"  ENFORCE: {e['class']} ({e['count']}x, {', '.join(e['repos'])})")
for e in recurred:
    lines.append(f"  PROMOTE: {e['class']} — rule {e['rule']} not holding "
                 f"({e['count_after']} hits since)")
for e in rule:
    lines.append(f"  RULE: {e['class']} ({e['count']}x)")
if d["malformed_lines"]:
    lines.append(f"  WARN: {len(d['malformed_lines'])} malformed ledger line(s)")
    actionable += 1

print(actionable)
print("\n".join(lines))
PY
)

ACTIONABLE=$(printf '%s' "$SUMMARY" | head -1)
BODY=$(printf '%s' "$SUMMARY" | tail -n +2)

echo "$(stamp) actionable=$ACTIONABLE" >> "$LOG"
echo "$BODY" >> "$LOG"

if [[ "${ACTIONABLE:-0}" == "0" ]]; then
  echo "$(stamp) ledger clean — no reminder raised" >> "$LOG"
  exit 0
fi

# Something earned promotion. macOS Reminders is the example notification
# mechanism — swap for whatever you actually check daily.
REMINDER_BODY="$BODY

Run the lessons-audit skill to write the guards. Full report: $OUT"

/usr/bin/osascript <<APPLESCRIPT >> "$LOG" 2>&1
tell application "Reminders"
  tell list "$REMINDER_LIST"
    make new reminder with properties {name:"Lessons audit — $ACTIONABLE failure class(es) earned promotion", body:"$(printf '%s' "$REMINDER_BODY" | sed 's/"/\\"/g')"}
  end tell
end tell
APPLESCRIPT

echo "$(stamp) reminder created" >> "$LOG"
