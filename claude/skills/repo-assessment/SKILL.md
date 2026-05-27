---
name: repo-assessment
description: Assess every project in your config — staging/main divergence, CI health, open PRs, stale branches, uncommitted work. Optionally auto-create ready integration→production PRs for repos with passing CI. Designed for nightly runs (via /loop or cron) but also useful on-demand.
allowed-tools: Bash(git *), Bash(gh *), Bash(mkdir *), Bash(date *), Read, Write, PushNotification
disable-model-invocation: true
---

# repo-assessment

Walks every project listed in `~/.claude/projects-config.json`, checks
each repo's state, and reports what needs attention. Optionally
auto-creates ready integration→production PRs where CI is green.

The skill **assesses, recommends, and prepares PRs** — the user does the
final merge.

## When to use

- Manually any time: `/repo-assessment`
- Automatically: schedule via `/loop` or cron for a nightly run

## Hard rules (read first)

- The **only** write action permitted is `gh pr create` for an
  integration→production PR, and **only** when CI on the integration
  branch is green.
- **Never merge a PR. Never push to production. Never push to staging.
  Never commit. Never delete branches.** Recommend those — user decides.
- Always check for an existing open integration→production PR **before**
  creating one. Never open a duplicate.
- Never recommend promoting a repo whose integration build is failing —
  flag it for a fix instead.
- Surface uncommitted local work as a heads-up only — never offer to
  commit or "clean up" the working tree.
- The skill is idempotent — running it twice the same day must not
  create duplicate PRs or duplicate report sections.

## Step 0 — Read config

Read `~/.claude/projects-config.json`. For each project in `projects[]`,
use `project.path` and `project.git`:

```json
"git": {
  "integration_branch": "staging",
  "production_branch": "main"
}
```

If `git` is absent, default to `staging` → `main`. If
`project.path` isn't a git repo (`git -C <path> rev-parse
--is-inside-work-tree` fails), flag it in the report.

Resolve each repo's `owner/repo` slug at runtime from origin:

```bash
git -C <project.path> remote get-url origin
```

Strip `git@github.com:` / `https://github.com/` and `.git` to get the
`<owner>/<repo>` slug for `gh`.

Read `reports.output_dir` from the config (default
`~/projects/nightly-assessments`) for the report file location.

## Step 1 — Gather data per repo (parallel)

For each project with a `git` block, run in parallel:

```bash
# Divergence — ahead_by = commits on integration not yet on production
gh api repos/<slug>/compare/<production>...<integration> \
  --jq '{ahead: .ahead_by, behind: .behind_by}'

# Open PRs
gh pr list --repo <slug> --state open \
  --json number,title,headRefName,baseRefName,reviewDecision,mergeable,isDraft,statusCheckRollup,updatedAt

# GitHub Actions health on integration (latest run)
gh run list --repo <slug> --branch <integration> --limit 1 \
  --json conclusion,status,workflowName,createdAt

# Branches — to spot stale feature branches
gh api repos/<slug>/branches --jq '.[].name'

# Uncommitted local work (only meaningful when run locally)
git -C <project.path> status --short
```

If the project lists a CI provider beyond GitHub Actions (e.g., the
config could grow a `ci` field later), check that too. For now, assume
GitHub Actions is the source of truth for "integration green."

**Integration is "green"** only when the latest GitHub Actions run on
the integration branch concluded `success` (or there is no Actions
workflow). A `WORKING` / `QUEUED` / `IN_PROGRESS` run means "not yet
green" — report it, do not promote yet.

For stale-branch detection, for each branch other than
integration/production/`master`/`demo`, get its last commit date:

```bash
gh api repos/<slug>/commits/<branch> --jq '.commit.committer.date'
```

A branch with no commit in **>14 days** is stale.

For any repo where `gh` is unavailable or unauthenticated, record that
as a flag and continue — do not abort the whole run.

## Step 2 — Decide per repo

For each repo with `ahead` (commits integration is ahead of production)
and `behind` (commits behind):

- **`ahead` == 0 and `behind` == 0** → "in sync — nothing to promote."
- **`ahead` == 0 and `behind` > 0** → "nothing to promote; integration is
  `<behind>` commits behind production." Flag if `behind` > ~20 — usually
  means integration needs a refresh from production.
- **`ahead` > 0 and an open integration→production PR already exists** →
  do NOT create another. Report as
  `PR #<n> open since <date>, <ahead> commits, awaiting merge` plus its
  `reviewDecision`, `mergeable`, and `statusCheckRollup` state.
- **`ahead` > 0, no PR, integration green** → create a ready (non-draft) PR:

  ```bash
  gh pr create --repo <slug> --base <production> --head <integration> \
    --title "Promote <integration> to <production> ($(date +%F))" \
    --body "Promotes <ahead> commits from <integration> to <production>.

  Opened automatically by repo-assessment. Review and merge manually —
  this PR was not merged for you.

  Latest integration commit: <hash> <subject>"
  ```

  Capture the PR number/URL from the command output.
- **`ahead` > 0, no PR, integration NOT green** → do NOT create a PR.
  Flag: `integration build failing — fix before promoting (<ahead> commits waiting)`.

Other findings:
- Open PRs that are NOT integration→production: approved + green +
  mergeable → recommend merge; stale/conflicted/draft → flag the reason.
- Stale feature branches (>14 days, not integration/production/master/demo)
  → flag "merge or delete."
- Non-git directories (something in `projects[]` whose path isn't a git
  repo) → flag "not under version control — recommend `git init` + a
  GitHub repo."

## Step 3 — Write the report

Compute the date once: `date +%F`. Write to
`<reports.output_dir>/<YYYY-MM-DD>-assessment.md`, **overwriting** any
existing file for that date (idempotent). Create the output dir if it
doesn't exist.

Structure:

```markdown
# Repo Assessment — <YYYY-MM-DD>

<one-line summary, e.g. "4 PRs created, 1 staging build failing, 3 actions need approval.">

## Repo status

| Repo | Integration ahead | CI | Open PRs | Note |
|------|-------------------|----|----------|------|
| <slug> | <N> | ✅ green | <M> | PR #<n> awaiting merge |
| <slug> | <N> | ❌ failing | <M> | <reason> |

## PRs created tonight

- <slug> PR #<n> — promotes <ahead> commits — <url>
(or "None — no eligible green repos with un-PR'd integration commits.")

## Recommended actions — your approval required

1. Merge <slug> PR #<n> — checks green, ready to ship.
2. Fix <slug> integration build before promoting — <N> commits waiting.
3. ...
(or "None.")

## Flags / attention needed

- <slug>: stale branch `feature/x` — last commit <N> days ago.
- <path>: not under version control.
(or "None.")

## Uncommitted local work

- <slug>: <N> modified files (heads-up only — not assessed for promotion).
(omit this section when run in an environment without local clones)
```

## Step 4 — Notify

Send one `PushNotification` (status `proactive`), under 200 chars, one
line, leading with what the user would act on. Example:

> Nightly assessment: 4 PRs created, 1 build failing, 3 actions need approval — see <reports.output_dir>/<YYYY-MM-DD>-assessment.md

## Step 5 — Interactive runs

When run manually (not via the schedule), also print the full report and
the numbered recommended-actions list inline so the user can act right
away. When run by the schedule, the report file + notification are enough.

## Step 6 — End with a Proof of Work line

This skill writes a report file, so the turn must end with a
`Proof of Work:` section (the Stop hook blocks otherwise — important
for unattended nightly runs). Keep it short:

```
Proof of Work:
- What changed: assessed N repos, created M integration→production PRs
- How I verified: ran gh api compare / pr list / run list per repo
- What I observed: <PRs created with numbers>, <flags>
- Not verified: none — read-only assessment + PR creation only
```

## Anti-patterns (never do)

- Creating a duplicate PR when one already exists. Always check first.
- Creating a PR when integration CI is failing. Flag the failing build instead.
- Auto-merging. The user owns the merge decision.
- Cleaning up uncommitted local work. That's never the assessment's job.
- Aborting the whole run when one repo is broken. Skip + flag, continue.
