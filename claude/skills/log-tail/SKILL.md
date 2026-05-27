---
name: log-tail
description: Tail logs for a deployed service — filtered by severity, time range, or pattern. Reads ~/.claude/projects-config.json `services[]` to find services by name and the cloud-provider-specific log command for each.
disable-model-invocation: true
---

# log-tail

Quickly tail logs for any deployed service in your config. The user
may specify a service, time range, severity filter, or search pattern.

## Step 0 — Read config

Read `~/.claude/projects-config.json`. Collect every `services[]` entry
across all projects:

```json
"services": [
  {
    "name": "api-prod",
    "kind": "cloud-run",
    "environment": "production",
    "cloud_project": "my-gcp-project",
    "service_name": "myapp-api"
  }
]
```

If no services are configured anywhere, refuse:

> No services configured. Add a `services` block to one of your projects
> in ~/.claude/projects-config.json (see
> claude-code-starter/claude/projects-config.json.example).

## Step 1 — Pick the target service

From the user's invocation:

- Service name explicit → match it against `services[].name`
- Service unspecified → list available services and ask. Or default to
  the staging-environment service if there's exactly one.

When in doubt, prefer staging over production (safer to look at,
typically more verbose logging anyway).

## Step 2 — Build the log command

Based on `service.kind`:

### `cloud-run` (GCP)

```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=<service.service_name>" \
  --project=<service.cloud_project> \
  --limit=<LIMIT> \
  --format="table(timestamp,severity,textPayload)" \
  --freshness=<TIMERANGE> \
  2>&1
```

Defaults: `--limit=30`, `--freshness=1h`.

### Other kinds (not implemented in v1)

If `service.kind` is something you don't know how to handle yet, refuse
clearly:

> Service "<name>" has kind "<kind>", which this skill doesn't support
> yet. Implement the command pattern for <kind> in
> ~/.claude/skills/log-tail/SKILL.md or use the cloud provider's CLI
> directly.

Don't guess at the command — wrong gcloud / aws / heroku invocations
waste minutes of confused output.

## Step 3 — Apply filters

Layer filters onto the base command based on the user's intent:

| User says | Add to filter |
|-----------|---------------|
| "errors only" / "any errors?" | `AND severity>=ERROR` |
| "search for X" | `AND textPayload=~"X"` (or `jsonPayload.message=~"X"` for structured logs) |
| "last hour" (default) | `--freshness=1h` |
| "last 24 hours" / "today" | `--freshness=24h` |
| "more detail" / "full payload" | switch `--format` to `json` |

Combine as needed:

```bash
"resource.type=cloud_run_revision AND \
 resource.labels.service_name=<service> AND \
 textPayload=~\"<pattern>\" AND \
 severity>=ERROR"
```

## Step 4 — Run the query, format results

Run via the `Bash` tool. For most cases the table format is the right
output (compact, readable):

```
TIMESTAMP                    SEVERITY  TEXT_PAYLOAD
2026-05-27T19:42:01.123Z     ERROR     KeyError: 'user_id' in routes/agreements.py:142
2026-05-27T19:41:58.001Z     WARNING   Slow query: SELECT * FROM ... took 2.4s
```

For JSON format (when the user wants full stack traces), present the
relevant fields per entry — don't dump raw JSON walls.

## Step 5 — If errors found, offer follow-up

When errors appear in the output, suggest next steps:

- "Want me to search the codebase for `<error message>`?"
- "Want me to check Sentry (if MCP is configured) for related issues?"
- "Want the full stack trace for entry #N?"

Don't auto-do these — the user may be on a different path.

## Anti-patterns (never do)

- Guessing the gcloud command when `service.kind` is unfamiliar — refuse
  clearly instead.
- Running against production by default. Staging first; prod when asked.
- Dumping unfiltered logs when the user clearly asked for "errors only" —
  filter at the query layer, not by post-processing.
- Tailing forever in foreground. This skill is one-shot ("show me the
  last N entries"); for live tailing the user should use the cloud
  provider's CLI directly.
