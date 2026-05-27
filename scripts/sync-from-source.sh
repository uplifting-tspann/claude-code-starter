#!/usr/bin/env bash
# sync-from-source.sh
#
# Diffs your live ~/.claude/ against this template repo's claude/ dir
# and helps you decide per-file what to promote (live → template),
# pull (template → live), or leave alone.
#
# Must be run from a checkout of claude-code-starter (it uses the
# repo's claude/ dir as the template side of the comparison).
#
# Modes:
#   default        Print a report (read-only). Categorizes every file.
#   --diff         Same as default, but include diffs for files that differ.
#   --interactive  Prompt per-file: promote/update/skip/diff.
#                  Interactive mode requires a TTY on stdin.
#   --dry-run      With --interactive: print what would happen, don't copy.
#
# Scope: rules/, skills/, hooks/. Skips CLAUDE.md, settings.json, and
# projects-config.json — those are user-personalized and don't sync.

set -euo pipefail

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

SHOW_DIFF=0
INTERACTIVE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: sync-from-source.sh [--diff] [--interactive] [--dry-run] [--help]

Diffs ~/.claude/{rules,skills,hooks} against this template repo's claude/
dir and reports differences. Helps keep your local install in sync with
the template (and vice versa) as both evolve.

Options:
  --diff          Include unified diffs in the report for files that differ.
                  Read-only; no changes.
  --interactive   For each difference, prompt: promote (LIVE→template),
                  update (template→LIVE), diff, or skip. Requires a TTY.
  --dry-run       With --interactive: print actions without copying.
                  Useful for previewing.
  --help          Show this help and exit.

Scope: rules/, skills/, hooks/ only. Skips CLAUDE.md, settings.json,
and projects-config.json — those are user-personalized and don't sync.

Workflow tip:
  1. Run this without flags every few weeks (or after big workflow shifts)
  2. Triage the report — which differences are general (promote to template)
     vs. project-specific (leave local)?
  3. Re-run with --interactive to actually make the moves
  4. Commit + push the template-side changes from the repo dir
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --diff)         SHOW_DIFF=1; shift ;;
    --interactive)  INTERACTIVE=1; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    --help|-h)      usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# Interactive mode requires a TTY on stdin
if [ "$INTERACTIVE" = 1 ] && [ ! -t 0 ]; then
  echo "ERROR: --interactive requires a TTY on stdin." >&2
  echo "Re-run without --interactive, or run from a real terminal (not a pipe)." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Path resolution
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_DIR/claude"
LIVE_DIR="$HOME/.claude"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "ERROR: Expected $TEMPLATE_DIR (this script's repo's claude/) to exist." >&2
  echo "Run this script from a checkout of claude-code-starter." >&2
  exit 1
fi

if [ ! -d "$LIVE_DIR" ]; then
  echo "ERROR: $LIVE_DIR doesn't exist yet — no live config to sync." >&2
  echo "Run scripts/install-claude-config.sh first." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Counters
# -----------------------------------------------------------------------------

IDENTICAL=0
DIFFERS=0
LIVE_ONLY=0
TEMPLATE_ONLY=0
ACTIONS_TAKEN=0

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

header() {
  printf '\n=== %s ===\n' "$1"
}

# Print a status line: STATUS  relative-path
status_line() {
  printf '  %-14s %s\n' "$1" "$2"
}

# Show the diff for a file, with safe headers
show_diff() {
  local live="$1"
  local template="$2"
  local rel="$3"

  echo ""
  echo "--- LIVE: ~/.claude/$rel"
  echo "+++ TEMPLATE: claude/$rel"
  diff -u "$live" "$template" || true
  echo ""
}

# Prompt the user. Echoes one character (lowercased) to stdout.
# $1 = prompt string
# $2 = allowed chars (e.g. "pus" for promote/update/skip)
prompt_choice() {
  local prompt="$1"
  local allowed="$2"
  local reply
  while true; do
    printf '  %s ' "$prompt" >&2
    IFS= read -r reply
    reply=$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]' | head -c 1)
    if [ -n "$reply" ] && [[ "$allowed" == *"$reply"* ]]; then
      printf '%s' "$reply"
      return 0
    fi
    echo "  (valid: $(echo "$allowed" | sed 's/./& /g'))" >&2
  done
}

# Copy a file with mkdir -p. Honors DRY_RUN.
copy_file() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ "$DRY_RUN" = 1 ]; then
    echo "  [dry-run] would $label: $src → $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo "  $label: $src → $dst"
    ACTIONS_TAKEN=$((ACTIONS_TAKEN + 1))
  fi
}

# Handle one file based on its status. Updates counters.
# $1 = status (IDENTICAL | DIFFERS | LIVE-ONLY | TEMPLATE-ONLY)
# $2 = relative path under the section dir (e.g. "no-glazing.md")
# $3 = section name (rules/skills/hooks) — used for diff path labeling
# $4 = full live path (may not exist for TEMPLATE-ONLY)
# $5 = full template path (may not exist for LIVE-ONLY)
handle_file() {
  local status="$1"
  local rel="$2"
  local section="$3"
  local live="$4"
  local template="$5"
  local section_rel="$section/$rel"

  case "$status" in
    IDENTICAL)
      status_line "IDENTICAL" "$section_rel"
      IDENTICAL=$((IDENTICAL + 1))
      ;;

    DIFFERS)
      status_line "DIFFERS" "$section_rel"
      DIFFERS=$((DIFFERS + 1))
      [ "$SHOW_DIFF" = 1 ] && show_diff "$live" "$template" "$section_rel"

      if [ "$INTERACTIVE" = 1 ]; then
        local choice
        choice=$(prompt_choice "[p]romote LIVE→template, [u]pdate template→LIVE, [d]iff, [s]kip:" "puds")
        case "$choice" in
          p) copy_file "$live" "$template" "promote" ;;
          u) copy_file "$template" "$live" "update" ;;
          d) show_diff "$live" "$template" "$section_rel"
             local again
             again=$(prompt_choice "Now [p]romote, [u]pdate, [s]kip:" "pus")
             case "$again" in
               p) copy_file "$live" "$template" "promote" ;;
               u) copy_file "$template" "$live" "update" ;;
               s) ;;
             esac
             ;;
          s) ;;
        esac
      fi
      ;;

    LIVE-ONLY)
      status_line "LIVE ONLY" "$section_rel"
      LIVE_ONLY=$((LIVE_ONLY + 1))

      if [ "$INTERACTIVE" = 1 ]; then
        local choice
        choice=$(prompt_choice "[p]romote to template, [s]kip (keep local):" "ps")
        case "$choice" in
          p) copy_file "$live" "$template" "promote" ;;
          s) ;;
        esac
      fi
      ;;

    TEMPLATE-ONLY)
      status_line "TEMPLATE ONLY" "$section_rel"
      TEMPLATE_ONLY=$((TEMPLATE_ONLY + 1))

      if [ "$INTERACTIVE" = 1 ]; then
        local choice
        choice=$(prompt_choice "[u]pdate LIVE (pull from template), [s]kip:" "us")
        case "$choice" in
          u) copy_file "$template" "$live" "update" ;;
          s) ;;
        esac
      fi
      ;;
  esac
}

# Walk a single section directory (rules / skills / hooks) and categorize
# every file. Skips README.md files (template documentation only).
walk_section() {
  local section="$1"
  local live_root="$LIVE_DIR/$section"
  local template_root="$TEMPLATE_DIR/$section"

  # Capitalize first letter portably (macOS ships bash 3.2; ${var^} is bash 4+)
  local label
  label="$(printf '%s' "$section" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
  header "$label"

  # Collect every file from both sides, normalized to relative paths.
  # Note: -printf is GNU-only; macOS ships BSD find. Use cd + ./ stripping.
  local files
  files=$( {
    [ -d "$live_root" ] && ( cd "$live_root" && find . -type f ! -name 'README.md' | sed 's|^\./||' )
    [ -d "$template_root" ] && ( cd "$template_root" && find . -type f ! -name 'README.md' | sed 's|^\./||' )
  } | sort -u )

  if [ -z "$files" ]; then
    echo "  (no files in either side)"
    return
  fi

  while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    local live_path="$live_root/$rel"
    local template_path="$template_root/$rel"

    if [ -f "$live_path" ] && [ -f "$template_path" ]; then
      if cmp -s "$live_path" "$template_path"; then
        handle_file "IDENTICAL" "$rel" "$section" "$live_path" "$template_path"
      else
        handle_file "DIFFERS" "$rel" "$section" "$live_path" "$template_path"
      fi
    elif [ -f "$live_path" ]; then
      handle_file "LIVE-ONLY" "$rel" "$section" "$live_path" "$template_path"
    elif [ -f "$template_path" ]; then
      handle_file "TEMPLATE-ONLY" "$rel" "$section" "$live_path" "$template_path"
    fi
  done <<< "$files"
}

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------

cat <<EOF
claude-code-starter — sync-from-source.sh

Template:    $TEMPLATE_DIR
Live:        $LIVE_DIR
Mode:        $( [ "$INTERACTIVE" = 1 ] && echo 'INTERACTIVE' || echo 'REPORT' )$( [ "$SHOW_DIFF" = 1 ] && echo ' + diffs' )$( [ "$DRY_RUN" = 1 ] && echo ' (DRY RUN)' )

Scope: rules/, skills/, hooks/
Skipped: CLAUDE.md, settings.json, projects-config.json (user-personalized)
EOF

# -----------------------------------------------------------------------------
# Walk each section
# -----------------------------------------------------------------------------

walk_section "rules"
walk_section "skills"
walk_section "hooks"

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

cat <<EOF

=== Summary ===
  IDENTICAL:      $IDENTICAL
  DIFFERS:        $DIFFERS
  LIVE ONLY:      $LIVE_ONLY   (in your install but not template)
  TEMPLATE ONLY:  $TEMPLATE_ONLY   (in template but not your install)
EOF

if [ "$INTERACTIVE" = 1 ]; then
  echo "  Actions taken:  $ACTIONS_TAKEN"
  if [ "$ACTIONS_TAKEN" -gt 0 ] && [ "$DRY_RUN" = 0 ]; then
    cat <<'EOF'

Next steps:
  - Review template-side changes:  git -C "$(dirname "$(dirname "$(realpath "$0")")")" diff
  - Commit and push promoted files so others get them
  - Restart Claude Code so newly-pulled rules/skills take effect
EOF
  fi
else
  cat <<'EOF'

Next steps:
  - For DIFFERS: re-run with --diff to see what changed
  - For LIVE ONLY: copy to template/ if generally useful (file → claude/ in this repo)
  - For TEMPLATE ONLY: copy to ~/.claude/ if you want it (file → ~/.claude/)
  - Or re-run with --interactive to handle per-file with prompts
EOF
fi
