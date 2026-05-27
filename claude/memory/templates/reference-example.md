---
name: reference-sentry-project
description: Where errors are tracked. Sentry org "acme", project "backend-prod"; alert routing in #eng-alerts Slack channel.
metadata:
  type: reference
---

Production errors flow to **Sentry org `acme`, project `backend-prod`**.
Staging errors go to project `backend-staging` (same org).

**Alert routing:** Critical issues page #eng-oncall via Sentry's
PagerDuty integration; non-critical alerts post to #eng-alerts Slack.

**Dashboard URL:** `https://acme.sentry.io/projects/backend-prod/`

**When to check Sentry:** After deploying, when investigating a
user-reported bug, when triaging an oncall page, or when answering
"is this happening for other users too?"

**MCP integration:** Claude can query Sentry directly via the
`mcp__claude_ai_Sentry__*` tools — use `search_issues` to find
recent occurrences, `analyze_issue_with_seer` for AI-assisted root
cause analysis on a specific issue ID.

Related: [[reference-deploy-pipeline]], [[reference-oncall-rotation]].
