#!/bin/bash
# guard-dangerous-bash.sh — PreToolUse(Bash) guard that hard-blocks irreversible
# / destructive operations the model would otherwise have to *remember* not to
# do. Enforcement the harness runs beats enforcement the model must recall.
#
# Emits {"decision":"block","reason":"..."} on stdout and exits 0 — this is
# the protocol Claude Code's PreToolUse hooks expect for a block decision.
# (A hook that instead does `echo "reason"; exit 1` is NOT reliably treated
# as blocking by every harness version — prefer the JSON-decision form.)
#
# Wire it up in settings.json:
#   "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [
#     { "type": "command", "command": "/absolute/path/guard-dangerous-bash.sh" }
#   ] } ] }
#
# Test in isolation:
#   echo '{"tool_input":{"command":"git push origin main"}}' \
#     | ./guard-dangerous-bash.sh
#
# ---------------------------------------------------------------------------
# CONFIG — EDIT THIS BLOCK. Everything below it is generic and shouldn't need
# changes. An empty value disables that specific check.
# ---------------------------------------------------------------------------

# Your protected/production branch(es), space-separated. Pushing directly to
# any of these is blocked — promotion should go through a PR.
PROTECTED_BRANCHES="main"

# Cloud Run / any gcloud-style deploy tool: block the destructive "replace all
# env vars" flag form. Leave blank to skip this check entirely if you don't
# use gcloud.
CHECK_GCLOUD_ENV_WIPE=1

# Production database name(s), space-separated, as they appear in SQL/connection
# strings. Matched with a trailing non-underscore boundary so "myapp_prod" does
# NOT also match "myapp_prod_staging". Leave blank to skip this check.
PROD_DATABASES="myapp_prod"

# ---------------------------------------------------------------------------
# Generic below this line.
# ---------------------------------------------------------------------------

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

# Strip shell comments (whitespace-then-#, per line) so a comment mentioning
# "main" / "--set-env-vars" can't false-trigger a guard.
scan=$(printf '%s' "$cmd" | sed 's/[[:space:]]#.*$//')

block() {
  local reason
  reason=$(jq -Rn --arg r "$1" '$r')   # JSON-escape
  printf '{"decision":"block","reason":%s}\n' "$reason"
  exit 0
}

is_git_push=0
printf '%s' "$scan" | grep -qE 'git[[:space:]]+push' && is_git_push=1

# 1. Never push directly to a protected branch. Anchors the destination to the
#    push segment ([^;&|]* stops at a chained command), so `HEAD:staging`,
#    `main:staging`, `git log origin/main..HEAD`, and
#    `git checkout main && git push origin staging` are all left alone.
if [ -n "$PROTECTED_BRANCHES" ]; then
  for branch in $PROTECTED_BRANCHES; do
    if printf '%s' "$scan" | grep -qE "git[[:space:]]+push[^;&|]*(:${branch}|[[:space:]]${branch})([[:space:]]|\$)"; then
      block "BLOCKED: pushing directly to '$branch'. Promotion should go through a PR, not a direct push."
    fi
  done
fi

# 2. No history rewrite on shared branches.
if printf '%s' "$scan" | grep -qE 'git[[:space:]]+commit[[:space:]].*--amend'; then
  block "BLOCKED: git commit --amend rewrites history other sessions may share on this branch. Add a follow-up commit instead."
fi
if printf '%s' "$scan" | grep -qE 'git[[:space:]]+rebase([[:space:]]|$)'; then
  block "BLOCKED: git rebase rewrites shared-branch history. Not allowed on branches other sessions build on."
fi
if [ "$is_git_push" = 1 ] && \
   printf '%s' "$scan" | grep -qE '(--force([[:space:]]|=|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$))'; then
  block "BLOCKED: force-push rewrites remote history other sessions have pulled. Never force-push a shared branch."
fi

# 3. Cloud Run (or similar) env-var wipe. The "replace all" flag form REPLACES
#    every existing var/secret (a whole-service outage class).
if [ -n "$CHECK_GCLOUD_ENV_WIPE" ] && \
   printf '%s' "$scan" | grep -qE 'gcloud.*run.*(--set-env-vars|--set-secrets)([[:space:]]|=)'; then
  block "BLOCKED: --set-env-vars / --set-secrets REPLACES all existing vars/secrets (wipes the rest). Use --update-env-vars / --update-secrets."
fi

# 4. Destructive SQL against a PRODUCTION database by name (the trailing
#    [^_] excludes lookalikes like myapp_prod_staging).
if [ -n "$PROD_DATABASES" ] && \
   printf '%s' "$scan" | grep -qiE '(DROP[[:space:]]+TABLE|TRUNCATE|DELETE[[:space:]]+FROM)'; then
  for db in $PROD_DATABASES; do
    if printf '%s' "$scan" | grep -qE "${db}([^_]|\$)"; then
      block "BLOCKED: destructive SQL (DROP/TRUNCATE/DELETE) naming a PRODUCTION database. If truly intended, run it manually with explicit confirmation."
    fi
  done
fi

exit 0
