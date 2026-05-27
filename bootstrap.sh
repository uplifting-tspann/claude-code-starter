#!/usr/bin/env bash
# bootstrap.sh
#
# One-shot machine setup for the claude-code-starter workflow on macOS.
#
# Idempotent — every step is safe to re-run. Destructive moves are gated
# behind explicit prompts or flags; nothing in your ~/.claude is overwritten
# without an opt-in.
#
# What it does, in order:
#   1. Confirm macOS + Xcode Command Line Tools.
#   2. Install Homebrew if missing (official one-liner; prompts for sudo).
#   3. Run `brew bundle` against the included Brewfile.
#   4. Check whether the Claude Code CLI is installed; print install
#      instructions if not (we don't auto-install; Anthropic's official
#      install procedure may change).
#   5. Run scripts/install-claude-config.sh in default (skip-existing) mode.
#   6. Print auth + next-step instructions.

set -euo pipefail

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

DRY_RUN=0
SKIP_BREW=0
SKIP_CLAUDE_CONFIG=0
FORCE_CLAUDE_CONFIG=0

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--dry-run] [--skip-brew] [--skip-claude-config]
                    [--force-claude-config] [--help]

Bootstraps a macOS machine for the claude-code-starter workflow.

Options:
  --dry-run               Print what each step would do; make no changes.
  --skip-brew             Skip Homebrew install + brew bundle (useful if you
                          manage packages another way, or have already done this).
  --skip-claude-config    Skip running scripts/install-claude-config.sh
                          (run it later by hand if/when you're ready).
  --force-claude-config   Pass --force through to install-claude-config.sh
                          (overwrite existing ~/.claude files with backups).
  --help                  Show this help and exit.

The script is idempotent — running it a second time is safe and will skip
anything already installed.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)              DRY_RUN=1; shift ;;
    --skip-brew)            SKIP_BREW=1; shift ;;
    --skip-claude-config)   SKIP_CLAUDE_CONFIG=1; shift ;;
    --force-claude-config)  FORCE_CLAUDE_CONFIG=1; shift ;;
    --help|-h)              usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# -----------------------------------------------------------------------------
# Path resolution
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
BREWFILE="$REPO_DIR/Brewfile"
INSTALL_CONFIG="$REPO_DIR/scripts/install-claude-config.sh"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

header() {
  printf '\n=== %s ===\n' "$1"
}

run_or_dryrun() {
  if [ "$DRY_RUN" = 1 ]; then
    echo "  would run: $*"
  else
    "$@"
  fi
}

# -----------------------------------------------------------------------------
# Banner
# -----------------------------------------------------------------------------

cat <<EOF
claude-code-starter — bootstrap.sh

This script will set up your macOS machine for the claude-code-starter workflow.

Repo:        $REPO_DIR
Brewfile:    $BREWFILE
Mode:        $( [ "$DRY_RUN" = 1 ] && echo 'DRY RUN (no changes)' || echo 'live' )

Steps:
  1. Verify macOS + Xcode CLI tools
  2. Install Homebrew + run brew bundle  $( [ "$SKIP_BREW" = 1 ] && echo '(SKIPPED)' )
  3. Check Claude Code CLI install
  4. Install ~/.claude config skeleton    $( [ "$SKIP_CLAUDE_CONFIG" = 1 ] && echo '(SKIPPED)' )
  5. Print auth + next-step instructions
EOF

# -----------------------------------------------------------------------------
# 1. macOS + Xcode CLI tools
# -----------------------------------------------------------------------------

header "1. macOS + Xcode CLI tools"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: This bootstrap is macOS-only." >&2
  echo "On Linux you'll need to translate the Brewfile to your package manager and run install-claude-config.sh by hand." >&2
  exit 1
fi
echo "  macOS detected ($(sw_vers -productVersion))."

if ! xcode-select -p >/dev/null 2>&1; then
  echo "  Xcode Command Line Tools are NOT installed."
  if [ "$DRY_RUN" = 1 ]; then
    echo "  would run: xcode-select --install"
  else
    echo "  Triggering installer (this opens a GUI prompt; finish it, then re-run this script)."
    xcode-select --install || true
    echo ""
    echo "Re-run ./bootstrap.sh once the Xcode CLI tools install finishes."
    exit 0
  fi
else
  echo "  Xcode CLI tools installed at: $(xcode-select -p)"
fi

# -----------------------------------------------------------------------------
# 2. Homebrew + brew bundle
# -----------------------------------------------------------------------------

if [ "$SKIP_BREW" = 1 ]; then
  header "2. Homebrew (SKIPPED)"
else
  header "2. Homebrew"

  if ! command -v brew >/dev/null 2>&1; then
    echo "  Homebrew is NOT installed."
    if [ "$DRY_RUN" = 1 ]; then
      echo "  would run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    else
      echo "  Installing via the official one-liner..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

      # On Apple Silicon, brew installs to /opt/homebrew and isn't on PATH by default.
      if [ -x /opt/homebrew/bin/brew ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [ -x /usr/local/bin/brew ]; then
        eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi
  else
    echo "  Homebrew installed at: $(command -v brew)"
  fi

  if [ -f "$BREWFILE" ]; then
    echo ""
    echo "  Running brew bundle against $BREWFILE..."
    run_or_dryrun brew bundle --file="$BREWFILE"
  else
    echo "  No Brewfile found at $BREWFILE — skipping brew bundle."
  fi
fi

# -----------------------------------------------------------------------------
# 3. Claude Code CLI
# -----------------------------------------------------------------------------

header "3. Claude Code CLI"

if command -v claude >/dev/null 2>&1; then
  echo "  Claude Code CLI installed at: $(command -v claude)"
  echo "  Version: $(claude --version 2>/dev/null || echo 'unknown')"
else
  cat <<'EOF'
  Claude Code CLI is NOT installed.

  Install it via the official channel — see:
    https://docs.claude.com/en/docs/agents-and-tools/claude-code/overview

  (We don't auto-install because Anthropic's recommended install procedure
  may change. Once it's installed, re-run ./bootstrap.sh to continue, or
  skip ahead and run scripts/install-claude-config.sh by hand.)
EOF
fi

# -----------------------------------------------------------------------------
# 4. ~/.claude config skeleton
# -----------------------------------------------------------------------------

if [ "$SKIP_CLAUDE_CONFIG" = 1 ]; then
  header "4. ~/.claude config skeleton (SKIPPED)"
  echo "  Run by hand later: $INSTALL_CONFIG"
else
  header "4. ~/.claude config skeleton"

  if [ ! -x "$INSTALL_CONFIG" ]; then
    echo "  ERROR: $INSTALL_CONFIG not found or not executable." >&2
    echo "  Run: chmod +x $INSTALL_CONFIG" >&2
    exit 1
  fi

  INSTALL_ARGS=()
  [ "$DRY_RUN" = 1 ]              && INSTALL_ARGS+=(--dry-run)
  [ "$FORCE_CLAUDE_CONFIG" = 1 ]  && INSTALL_ARGS+=(--force)

  "$INSTALL_CONFIG" "${INSTALL_ARGS[@]}"
fi

# -----------------------------------------------------------------------------
# 5. Auth + next steps
# -----------------------------------------------------------------------------

header "5. Auth + next steps"

cat <<'EOF'
The bootstrap is functional but auth is manual on purpose — these prompts
open browser windows / require interactive confirmation.

When you're ready, run each of these (each is idempotent — safe to re-run):

  # GitHub CLI auth (needed for `gh repo create --template` and PR work)
  gh auth login

  # gcloud auth (needed if you use GCP)
  gcloud auth login
  gcloud auth application-default login

  # Claude Code CLI auth (if not already authenticated)
  claude login

Open a new shell after running auth so the credentials are picked up.

What's next:
  - Edit ~/.claude/settings.json to add MCP servers, project paths, or
    custom permissions for your stack.
  - Start a new project with:
      gh repo create my-project --template uplifting-tspann/claude-code-starter --public --clone
  - Read the WHY.md (coming soon) for the reasoning behind each rule/pattern.
EOF
