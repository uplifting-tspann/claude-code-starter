---
name: error-triage
description: Pull and triage recent unresolved errors from your error tracker across all projects — group by frequency, trace each to the source file in the local repo, and recommend fixes. Reads ~/.claude/projects-config.json for the per-project error-tracker slugs and source paths.
disable-model-invocation: true
---

# error-triage

Triage recent production errors across every project in your config. The
user may optionally narrow to one project or a time range.

> **Stack assumption:** the worked example below uses **Sentry** (REST API
> via `curl`, or the Sentry MCP server if you have it connected). The
> *shape* of the skill — fetch unresolved issues → rank by frequency →
> pull the latest event's stack trace → grep the local repo for the
> failing frame → recommend a fix — is tracker-agnostic. If you use
> Rollbar / Bugsnag / Datadog / Honeybadger / GCP Error Reporting,
> replace the two `curl` calls in Step 2 and Step 4 with that tracker's
> equivalents and everything else carries over unchanged.

## Step 0 — Read config

Read `~/.claude/projects-config.json`. This skill uses an optional
`error_tracking` block per project:

```json
{
  "name": "api",
  "path": "~/projects/api",
  "backend": { "path": "." },
  "error_tracking": {
    "provider": "sentry",
    "org_slug": "YOUR-ORG-SLUG",
    "project_slug": "YOUR-PROJECT-SLUG",
    "source_paths": ["backend"]
  }
}
```

- `org_slug` / `project_slug` — as they appear in your tracker's URLs
  (e.g. `https://sentry.io/organizations/<org_slug>/projects/<project_slug>/`).
- `source_paths` — directories **relative to `project.path`** to grep
  when tracing a stack frame back to source. Optional; defaults to the
  project's `backend.path` / `frontend.path` if present, else the whole
  project path.

If no project has an `error_tracking` block, refuse:

> No error tracking configured. Add an `error_tracking` block to at least
> one project in `~/.claude/projects-config.json` (see
> `claude-code-starter/claude/projects-config.json.example`).

Stop and report — don't proceed.

## Step 1 — Verify credentials

Sentry's REST API needs an auth token:

```bash
echo "${SENTRY_AUTH_TOKEN:+set}"
```

If unset, tell the user:

> Set your error-tracker token first:
> `export SENTRY_AUTH_TOKEN=<your-token>`
>
> Create one at https://sentry.io/settings/account/api/auth-tokens/
> Required scopes: `project:read`, `event:read`.

Do NOT proceed without a token. (If the user has the **Sentry MCP server**
connected instead, skip this step entirely and use the MCP tools —
`search_issues` / `get_sentry_resource` — in place of the `curl` calls
below. The MCP path is preferred when available: it handles auth for you.)

## Step 2 — Fetch unresolved issues per project

For each configured project (or just the one the user named), fetch recent
unresolved issues, sorted by frequency:

```bash
curl -s -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/projects/<ORG_SLUG>/<PROJECT_SLUG>/issues/?query=is:unresolved&statsPeriod=24h&sort=freq" \
  | python3 -c "
import json, sys
for i in json.load(sys.stdin)[:10]:
    print(f\"[{i['shortId']}] {i['id']} | {i['title']} | {i['count']} events | last: {i['lastSeen']} | {i.get('level','?')}\")"
```

Default `statsPeriod` is `24h`; honor the user's range if they gave one
(`1h`, `7d`, `14d`).

Run all projects **in parallel** (one `Bash` call each in the same block)
when no specific project was requested.

## Step 3 — Summarize as a triage table

Present everything ranked by event count across all projects — the whole
point is to see *what is on fire right now*, not to read per-project
reports:

| # | Project | Issue | Events | Last Seen | Level |
|---|---------|-------|--------|-----------|-------|
| 1 | api | ProgrammingError: relation "foo" does not exist | 47 | 2 min ago | error |
| 2 | frontend-app | TypeError: Cannot read property 'id' of undefined | 12 | 1 hr ago | error |

Note anything that looks like a **new** regression (high count, first seen
recently) — that's usually the thing worth acting on.

## Step 4 — Deep dive on the top issues

For the top 3 by event count, pull the latest event and extract the
exception + the last few stack frames:

```bash
curl -s -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  "https://sentry.io/api/0/issues/<ISSUE_ID>/events/latest/" \
  | python3 -c "
import json, sys
event = json.load(sys.stdin)
for e in event.get('entries', []):
    if e['type'] != 'exception':
        continue
    for val in e['data']['values']:
        print(f\"Type:  {val['type']}\")
        print(f\"Value: {val['value']}\")
        for frame in (val.get('stacktrace') or {}).get('frames', [])[-3:]:
            print(f\"  {frame.get('filename','?')}:{frame.get('lineNo','?')} in {frame.get('function','?')}\")"
```

The **last** frames are the interesting ones — that's where it actually
blew up, not the framework entry point.

## Step 5 — Trace back to local source

For each top issue, map the failing frame to a local file using the
project's `error_tracking.source_paths` (falling back to `backend.path` /
`frontend.path`). Then `Grep` / `Read` the code around that line.

```
Issue: KeyError: 'user_id'
Frame: routes/agreements.py:142
→ grep in <project.path>/<source_path>/routes/agreements.py
```

Show the actual code context. A stack trace without the surrounding code
is a guess; the code is the evidence.

## Step 6 — Recommend actions

For each top issue, report:

1. **Root cause** — what's actually wrong, grounded in the code you just
   read (not inferred from the error string alone)
2. **Fix** — the specific change, with the file and line
3. **Priority**:
   - **critical** — 500s on a core path, data loss, money-affecting
   - **high** — user-facing errors on a common path
   - **medium** — errors on an edge path, noisy warnings
   - **low** — cosmetic, third-party noise, already-handled exceptions

Then ask which ones the user wants fixed. **Don't start fixing
unprompted** — triage and repair are different jobs, and the user may
only want the picture.

## Anti-patterns (never do)

- Asserting a root cause from the error message alone without reading the
  source. The stack trace tells you *where*; only the code tells you *why*.
- Dumping raw JSON walls from the API. Extract and format.
- Sorting by recency instead of frequency. One noisy issue firing 400
  times matters more than a fresh one-off.
- Auto-fixing the top issue because it looked obvious. Triage first, ask,
  then fix.
- Silently skipping a project whose token/slug is misconfigured — say so,
  so the user knows that project wasn't covered.
