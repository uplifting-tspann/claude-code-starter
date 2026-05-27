#!/usr/bin/env bash
# install-claude-config.sh
#
# Installs the claude/ skeleton from this repo into ~/.claude/.
#
# By default, NEVER overwrites existing files in ~/.claude/. Files that already
# exist are skipped and reported. To overwrite, pass --force — existing files
# get a .bak.YYYYMMDDHHMMSS backup before being replaced.
#
# settings.json gets special handling: it has a YOUR-USER placeholder that
# gets replaced with the current $USER. If ~/.claude/settings.json already
# exists, the rendered template is written to ~/.claude/settings.json.suggested
# alongside it (so you can diff and merge by hand) rather than touched directly.
#
# README.md files inside claude/rules/, claude/skills/, claude/hooks/ are NOT
# installed — they're template documentation, not configuration.

set -euo pipefail

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

DRY_RUN=0
FORCE=0

usage() {
  cat <<'EOF'
Usage: install-claude-config.sh [--dry-run] [--force] [--help]

Installs the claude/ skeleton from this repo into ~/.claude/.

Options:
  --dry-run   Print what would be installed; make no changes.
  --force     Overwrite existing files (with .bak.timestamp backups).
  --help      Show this help and exit.

Default behavior is conservative: existing files are skipped. Re-run with
--force to overwrite anything that's already there.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force)   FORCE=1;   shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# -----------------------------------------------------------------------------
# Path resolution
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_DIR="$REPO_DIR/claude"
DEST_DIR="$HOME/.claude"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: Expected $SOURCE_DIR to exist." >&2
  echo "Run this script from a checkout of claude-code-starter." >&2
  exit 1
fi

# -----------------------------------------------------------------------------
# Counters (for summary)
# -----------------------------------------------------------------------------

INSTALLED=0
SKIPPED=0
OVERWRITTEN=0
SUGGESTED=0

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

# Print a header. Cosmetic only.
header() {
  printf '\n=== %s ===\n' "$1"
}

# Install a single file. Honors --dry-run, --force, and the skip-existing default.
#   $1  source path
#   $2  destination path
install_file() {
  local src="$1"
  local dst="$2"
  local rel="${dst#$HOME/}"

  if [ ! -e "$dst" ]; then
    if [ "$DRY_RUN" = 1 ]; then
      echo "  would install:  ~/$rel"
    else
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      echo "  installed:      ~/$rel"
    fi
    INSTALLED=$((INSTALLED + 1))
  elif [ "$FORCE" = 1 ]; then
    local bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
    if [ "$DRY_RUN" = 1 ]; then
      echo "  would overwrite (backup: ~/${bak#$HOME/}):  ~/$rel"
    else
      mv "$dst" "$bak"
      cp "$src" "$dst"
      echo "  overwrote (backup: ~/${bak#$HOME/}):  ~/$rel"
    fi
    OVERWRITTEN=$((OVERWRITTEN + 1))
  else
    echo "  skipped (exists; use --force to overwrite):  ~/$rel"
    SKIPPED=$((SKIPPED + 1))
  fi
}

# Install a directory recursively, treating each file inside as install_file.
# Skips README.md (template documentation, not user content).
#   $1  source directory
#   $2  destination directory
install_dir_files() {
  # Normalize: strip any trailing slash from src_dir so prefix removal below works.
  local src_dir="${1%/}"
  local dst_dir="${2%/}"
  local f
  while IFS= read -r f; do
    local rel="${f#$src_dir/}"
    install_file "$f" "$dst_dir/$rel"
  done < <(find "$src_dir" -type f ! -name 'README.md')
}

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------

cat <<EOF
claude-code-starter — install-claude-config.sh

Source:      $SOURCE_DIR
Destination: $DEST_DIR
Mode:        $( [ "$DRY_RUN" = 1 ] && echo 'DRY RUN (no changes)' || echo 'live' )
Force:       $( [ "$FORCE" = 1 ] && echo 'YES (existing files will be backed up + overwritten)' || echo 'no (existing files will be skipped)' )
User:        $USER (will be substituted for YOUR-USER in settings.json template)
EOF

if [ "$DRY_RUN" = 0 ]; then
  mkdir -p "$DEST_DIR/rules" "$DEST_DIR/skills" "$DEST_DIR/hooks" "$DEST_DIR/memory"
fi

# -----------------------------------------------------------------------------
# Rules
# -----------------------------------------------------------------------------

header "Rules"
install_dir_files "$SOURCE_DIR/rules" "$DEST_DIR/rules"

# -----------------------------------------------------------------------------
# Skills (each skill is a directory; install file-by-file inside)
# -----------------------------------------------------------------------------

header "Skills"
if [ -d "$SOURCE_DIR/skills" ]; then
  for skill_dir in "$SOURCE_DIR"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    local_name=$(basename "$skill_dir")
    install_dir_files "$skill_dir" "$DEST_DIR/skills/$local_name"
  done
fi

# -----------------------------------------------------------------------------
# Hooks (need chmod +x after copy)
# -----------------------------------------------------------------------------

header "Hooks"
for hook in "$SOURCE_DIR"/hooks/*.sh; do
  [ -f "$hook" ] || continue
  dst="$DEST_DIR/hooks/$(basename "$hook")"
  install_file "$hook" "$dst"
  if [ "$DRY_RUN" = 0 ] && [ -f "$dst" ]; then
    chmod +x "$dst"
  fi
done

# -----------------------------------------------------------------------------
# settings.json (special — username substitution, never auto-overwrite)
# -----------------------------------------------------------------------------

header "Settings"
src="$SOURCE_DIR/settings.json.template"
dst="$DEST_DIR/settings.json"
suggested="$DEST_DIR/settings.json.suggested"

if [ ! -f "$src" ]; then
  echo "  WARNING: $src not found — skipping settings.json install."
else
  if [ "$DRY_RUN" = 1 ]; then
    if [ ! -e "$dst" ]; then
      echo "  would install (with username $USER substituted):  ~/.claude/settings.json"
      INSTALLED=$((INSTALLED + 1))
    elif [ "$FORCE" = 1 ]; then
      bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
      echo "  would overwrite (backup: ~/${bak#$HOME/}):  ~/.claude/settings.json"
      OVERWRITTEN=$((OVERWRITTEN + 1))
    else
      echo "  would write suggested file (existing settings.json preserved):  ~/.claude/settings.json.suggested"
      SUGGESTED=$((SUGGESTED + 1))
    fi
  else
    rendered=$(mktemp)
    sed "s/YOUR-USER/$USER/g" "$src" > "$rendered"
    if [ ! -e "$dst" ]; then
      cp "$rendered" "$dst"
      echo "  installed (with username $USER substituted):  ~/.claude/settings.json"
      INSTALLED=$((INSTALLED + 1))
    elif [ "$FORCE" = 1 ]; then
      bak="$dst.bak.$(date +%Y%m%d%H%M%S)"
      mv "$dst" "$bak"
      cp "$rendered" "$dst"
      echo "  overwrote (backup: ~/${bak#$HOME/}):  ~/.claude/settings.json"
      OVERWRITTEN=$((OVERWRITTEN + 1))
    else
      cp "$rendered" "$suggested"
      echo "  wrote suggested file (existing settings.json preserved):  ~/.claude/settings.json.suggested"
      echo "                                                          → diff and merge by hand"
      SUGGESTED=$((SUGGESTED + 1))
    fi
    rm "$rendered"
  fi
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

cat <<EOF

=== Summary ===
  Installed:    $INSTALLED
  Skipped:      $SKIPPED   ($( [ "$SKIPPED" -gt 0 ] && echo 'use --force to overwrite' || echo 'no conflicts' ))
  Overwritten:  $OVERWRITTEN
  Suggested:    $SUGGESTED  (written as .suggested alongside existing files)

$( [ "$DRY_RUN" = 1 ] && echo 'DRY RUN — no actual changes were made.' )
EOF

if [ "$DRY_RUN" = 0 ] && [ "$INSTALLED" -gt 0 ]; then
  cat <<'EOF'

Next steps:
  1. Open ~/.claude/settings.json and verify the hook path resolves on your machine.
  2. Restart any open Claude Code sessions so the new rules/hooks load.
  3. Try a test turn that edits a file — confirm the proof-stop-hook fires
     if you forget to include a "Proof of Work:" section.
EOF
fi
