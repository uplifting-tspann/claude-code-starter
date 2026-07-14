#!/bin/bash
# protect-production.sh — blocks destructive operations against production.
#
# Event:   PreToolUse, matcher `Bash` (wire it up in settings.json).
# Stdin:   the hook's JSON payload (includes tool_input.command).
# Exit 0 = allow the command to run.
# Exit 1 = block. Stdout/stderr is surfaced as the reason.
#
# This is a guardrail, not a security boundary. It catches the "oh no, wrong
# database" class of mistake before it executes. It does not stop a determined
# actor, and it is not a substitute for least-privilege DB credentials.
#
# Test it in isolation:
#   echo '{"tool_input":{"command":"psql -d myapp_prod -c \"TRUNCATE users\""}}' \
#     | ./protect-production.sh; echo "exit=$?"

# ---------------------------------------------------------------------------
# CONFIG — EDIT THIS BLOCK. These are the things you never want touched by
# accident. Everything below the block is generic and shouldn't need changes.
# ---------------------------------------------------------------------------

# Production database names, as they appear in a psql/mysql connection string.
# The match is anchored so `myapp_prod` does NOT also match `myapp_prod_staging`.
# Add every prod DB you have; leave staging/dev DBs OUT (that's the point).
PROD_DATABASES=(
  "myapp_prod"
  "myapp_analytics_prod"
)

# Production branches that must never be force-pushed or hard-reset.
PROD_BRANCHES=(
  "main"
  "master"
  "production"
)

# Deployed service names that must not be deleted / manually redeployed
# out-of-band (deploys should go through CI). Leave the array empty to skip
# this check entirely.
PROD_SERVICES=(
  "myapp-api"
  "myapp-worker"
)

# Cloud project / account identifiers that mean "this is production".
# Leave the array empty to skip this check.
PROD_CLOUD_PROJECTS=(
  "my-gcp-project-prod"
)

# ---------------------------------------------------------------------------
# END CONFIG
# ---------------------------------------------------------------------------

INPUT=$(cat)

# Join an array into a regex alternation: (a|b|c)
join_alt() {
  local IFS='|'
  echo "($*)"
}

block() {
  echo "BLOCKED: $1"
  echo "$2"
  exit 1
}

# --- 1. Destructive SQL against a production database -----------------------
# DROP TABLE / DROP DATABASE / TRUNCATE / DELETE FROM / ALTER ... DROP COLUMN
# appearing in the same command as a production DB name.
#
# The [^_[:alnum:]] guard after the DB name prevents `myapp_prod` from matching
# `myapp_prod_staging` — without it, this hook would block the very databases
# it's supposed to let you work in.
if [ ${#PROD_DATABASES[@]} -gt 0 ]; then
  DB_ALT=$(join_alt "${PROD_DATABASES[@]}")
  if echo "$INPUT" | grep -qiE "(DROP TABLE|DROP DATABASE|TRUNCATE|DELETE FROM|DROP COLUMN).*${DB_ALT}([^_[:alnum:]]|\"|$)"; then
    block "destructive SQL detected against a production database." \
          "If this is intentional, run it manually via your DB client with explicit confirmation."
  fi
  # Same pair, reversed order (the DB name often precedes the verb in a
  # `psql -d prod -c "TRUNCATE ..."` invocation).
  if echo "$INPUT" | grep -qiE "${DB_ALT}([^_[:alnum:]]|\"|$).*(DROP TABLE|DROP DATABASE|TRUNCATE|DELETE FROM|DROP COLUMN)"; then
    block "destructive SQL detected against a production database." \
          "If this is intentional, run it manually via your DB client with explicit confirmation."
  fi
fi

# --- 2. Force-push / hard-reset against a production branch -----------------
if [ ${#PROD_BRANCHES[@]} -gt 0 ]; then
  BRANCH_ALT=$(join_alt "${PROD_BRANCHES[@]}")
  if echo "$INPUT" | grep -qiE "git push.*(--force|-f)([^a-z]|$).*${BRANCH_ALT}([^a-z0-9_/-]|$)"; then
    block "force-push to a production branch." \
          "Promote via a pull request instead."
  fi
  if echo "$INPUT" | grep -qiE "git push.*origin.*${BRANCH_ALT}.*(--force|--force-with-lease)"; then
    block "force-push to a production branch." \
          "Promote via a pull request instead."
  fi
  if echo "$INPUT" | grep -qiE "git reset --hard.*origin/${BRANCH_ALT}([^a-z0-9_/-]|$)"; then
    block "hard reset against a production branch." \
          "This discards local work irreversibly. Do it manually if you mean it."
  fi
fi

# --- 3. Cloud env-var clobbering --------------------------------------------
# `gcloud run ... --set-env-vars` REPLACES every literal env var on the
# service — anything not in the command is silently deleted. `--update-env-vars`
# is additive and is almost always what was meant.
if echo "$INPUT" | grep -qE "gcloud.*run.*--set-env-vars"; then
  block "\`--set-env-vars\` removes every existing env var not named in the command." \
        "Use --update-env-vars (additive) instead. Same for --update-secrets over --set-secrets."
fi

# --- 4. Deleting / hand-deploying a production service ----------------------
if [ ${#PROD_SERVICES[@]} -gt 0 ]; then
  SVC_ALT=$(join_alt "${PROD_SERVICES[@]}")
  if echo "$INPUT" | grep -qiE "(gcloud .*(run|app) services delete|kubectl delete (deployment|service)|aws ecs delete-service|heroku apps:destroy).*${SVC_ALT}([^a-z0-9_-]|$)"; then
    block "deletion of a production service." \
          "If you really mean this, do it by hand in the console."
  fi
fi

# --- 5. Any command explicitly targeting a production cloud project ---------
# Only blocks the destructive verbs — read-only gcloud/aws calls against prod
# are fine and routine.
if [ ${#PROD_CLOUD_PROJECTS[@]} -gt 0 ]; then
  PROJ_ALT=$(join_alt "${PROD_CLOUD_PROJECTS[@]}")
  if echo "$INPUT" | grep -qiE "(delete|destroy|remove|purge).*${PROJ_ALT}([^a-z0-9_-]|$)"; then
    block "destructive command targeting a production cloud project." \
          "Read-only commands against production are fine; this one isn't read-only."
  fi
fi

exit 0
