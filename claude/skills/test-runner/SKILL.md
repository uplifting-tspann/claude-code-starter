---
name: test-runner
description: Run tests for a project — E2E, unit, smoke, or integration. Reads ~/.claude/projects-config.json for the per-project test commands. Smart-targets to the right command based on what the user asks for.
disable-model-invocation: true
---

# test-runner

Run tests across the projects listed in `~/.claude/projects-config.json`.
The user may specify a project, test type, or specific test file.

## Step 0 — Read config

Read `~/.claude/projects-config.json`. Expected per-project shape:

```json
{
  "name": "my-app",
  "path": "~/projects/my-app",
  "tests": {
    "unit": "npm test",
    "e2e": "npm run test:e2e",
    "smoke": "npm run test:e2e:smoke",
    "integration": "pytest -m integration"
  }
}
```

If the file doesn't exist OR no project has a `tests` block:

> No tests configured. Copy
> `claude-code-starter/claude/projects-config.json.example` to
> `~/.claude/projects-config.json`, edit it to add `tests` blocks
> per project, then re-invoke.

Stop and report — don't proceed.

## Step 1 — Determine target

From the user's invocation, infer:

- **Which project?** Match against `projects[].name`. If unspecified
  AND only one project has a matching test type, use it. If multiple
  match and the user didn't specify, ask: "Which project? (a, b, c)"
- **Which test type?** `unit`, `e2e`, `smoke`, `integration` —
  whatever keys exist under `tests` for that project. Default to
  `smoke` if available, else `unit`, else fail with a clear message.
- **Specific file?** Optional. If provided, append it to the command
  (most test runners accept a positional path argument).

## Step 2 — Build the command

```
cd <expanded project.path>
<the test command from project.tests[type]> [<file>]
```

Print the command before running so the user can interrupt if it's wrong:

```
Running in ~/projects/my-app:
  npm run test:e2e tests/auth.spec.ts
```

## Step 3 — Run it

Use the `Bash` tool. For long-running test suites:

- E2E typically: 5–20 min. Use a longer timeout; consider
  `run_in_background` for the longest suites so you can do other work
  while it runs.
- Unit tests: usually < 1 min. Foreground is fine.
- Smoke: usually < 2 min. Foreground is fine.

## Step 4 — Surface failures clearly

When tests fail, don't just dump the full output. Surface:

1. **The first failure** — file, line, assertion, expected vs. actual
2. **The count** — "3 failed, 47 passed" or similar
3. **Re-run command** — just the failing test, in the project context

Then offer to investigate or fix.

## Step 5 — Don't auto-rerun on failure

If the user asks for one run, give them one run. Don't loop on failures —
that's their call. Surface the failures and stop.

## When the user says "run all tests"

Iterate over `projects[]`, run each project's default test type
(`smoke` if present, else `unit`), and summarize at the end:

```
✓ project-a: 47 passed (smoke)
✗ project-b: 3 failed, 12 passed (smoke) — see above
✓ project-c: 89 passed (unit)
```

Use the `Bash` tool's parallel-invocation when projects are independent.

## Anti-patterns (never do)

- Running tests in a directory the config doesn't list. If the user wants
  to test a new project, ask them to add it to `projects-config.json` first.
- Inventing a test command not in the config. If `tests.e2e` is absent
  for a project, say "this project has no e2e command configured."
- Looping on failures or auto-retrying. The user decides whether to retry.
- Suppressing the actual command output — the user often wants to see it.
