---
name: deploy-check
description: Check recent CI/CD deploy status across all your repos — which builds are running, which failed, on what branch. Reads ~/.claude/projects-config.json for the per-project CI config. Offers to pull logs for failures.
allowed-tools: Bash(gcloud *), Bash(gh *)
disable-model-invocation: true
---

# deploy-check

Answer "did my last push actually deploy?" across every project in one
shot.

> **Stack assumption:** the worked example below uses **Google Cloud
> Build** (`gcloud builds list`). The skill is a thin wrapper around one
> query per repo plus a summary table — if you use GitHub Actions,
> CircleCI, GitLab CI, or anything else, swap the command in **Step 2**
> and the log command in **Step 4** for your provider's equivalent. Two
> drop-in alternatives are given at the bottom.

## Step 0 — Read config

Read `~/.claude/projects-config.json`. This skill uses an optional `ci`
block per project:

```json
{
  "name": "api",
  "path": "~/projects/api",
  "ci": {
    "provider": "cloud-build",
    "cloud_project": "YOUR-GCP-PROJECT-ID",
    "repo_name": "api"
  }
}
```

- `cloud_project` — the GCP project id that owns the Cloud Build triggers.
- `repo_name` — the value Cloud Build puts in `substitutions.REPO_NAME`
  (usually your GitHub repo name, without the org).

If no project has a `ci` block, refuse:

> No CI configured. Add a `ci` block to your projects in
> `~/.claude/projects-config.json` (see
> `claude-code-starter/claude/projects-config.json.example`).

Stop and report — don't guess at a cloud project id.

## Step 1 — Verify the CLI is authenticated

```bash
gcloud config get-value project 2>&1
```

If `gcloud` isn't installed or has no active credentials, say so plainly
and stop — a wall of auth errors is worse than one clear sentence.

## Step 2 — Query each repo's recent builds (in parallel)

One call per configured project, **all in the same tool block** so they run
concurrently:

```bash
gcloud builds list \
  --project=<ci.cloud_project> \
  --limit=3 \
  --filter="substitutions.REPO_NAME='<ci.repo_name>'" \
  --format="table(id,status,startTime,substitutions.BRANCH_NAME)" \
  2>&1
```

`--limit=3` is deliberate: you want the current build plus enough history
to see whether a failure is new or a repeat.

## Step 3 — Summarize

Present one table across all repos — the user wants the state of the world,
not five separate reports:

| Repo | Latest Build | Branch | Status | Started |
|------|-------------|--------|--------|---------|
| api | `a1b2c3d4` | staging | ✅ SUCCESS | 12 min ago |
| frontend-app | `e5f6g7h8` | staging | ⏳ WORKING | 2 min ago |
| docs-site | `i9j0k1l2` | main | ❌ FAILURE | 40 min ago |

Call out explicitly:

- **FAILURE** — this is the headline. Lead with it.
- **WORKING / QUEUED** — a deploy is in flight; the user may want to wait
  before testing.
- **A repo with no recent builds at all** — often means the push didn't
  land on a branch with a trigger, which is its own bug worth naming.

## Step 4 — On failure, offer the logs

Don't dump 500 lines unprompted. Offer, then fetch:

```bash
gcloud builds log <BUILD_ID> --project=<ci.cloud_project> 2>&1 | tail -40
```

When you do read a failing build, **find the step whose status is actually
`FAILURE`** — a build fails at the *earliest* failing step and every later
step is `QUEUED` and never ran. Blaming a step that never executed is the
classic wrong diagnosis:

```bash
gcloud builds describe <BUILD_ID> --project=<ci.cloud_project> \
  --format="json(steps)" 2>&1
```

Read *that* step's log, then trace the error to source.

## Swapping in a different CI provider

**GitHub Actions** (replace Step 2 and Step 4):

```bash
# Step 2 equivalent — recent runs for a repo
gh run list --repo <owner/repo> --limit 3 \
  --json databaseId,status,conclusion,headBranch,createdAt,displayTitle

# Step 4 equivalent — logs for a failed run
gh run view <RUN_ID> --repo <owner/repo> --log-failed
```

**GitLab CI:**

```bash
glab ci list --repo <group/project> --per-page 3
glab ci trace <PIPELINE_ID> --repo <group/project>
```

Keep Steps 0, 1, and 3 exactly as-is — only the query and the log command
are provider-specific.

## Anti-patterns (never do)

- Hardcoding a cloud project id or repo name instead of reading the config.
- Querying repos one at a time when they're independent — parallelize.
- Reporting "the build failed because of <the thing I most recently
  changed>" without reading the actual failing step's log.
- Dumping full build logs when the user only asked for status.
- Reporting SUCCESS on a stale build from yesterday as though it covers a
  push from five minutes ago — check the timestamp and say if the latest
  push doesn't appear to have triggered anything.
