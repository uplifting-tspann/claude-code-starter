# E2E Flow Tests — Mandatory Evolution Rule

## Core Principle

Your E2E flow test suite is a living artifact that MUST evolve with every feature addition and bug fix. This is automatic — not reminder-dependent.

## After Every Feature or Bug Fix

Before considering any work complete, answer these questions:

1. **Which flow test covers this path?** Find the relevant spec file in your E2E directory.
2. **Does that test still pass with the changes?** If selectors, API shapes, or UI copy changed, the test needs updating.
3. **Does a NEW test need to be written?** If the feature adds a user-facing flow not covered by existing tests, write one.
4. **Would this bug have been caught?** After fixing a bug, add a regression test that exercises the exact broken path.

## What Triggers Test Updates

| Change Type | Required Test Action |
|-------------|---------------------|
| New feature (wizard step, page, action) | Add flow test covering full user path |
| Bug fix | Add regression test to relevant flow spec |
| API endpoint added/changed | Update API validation in shared helpers + flow specs |
| UI component changed (buttons, selectors, copy) | Update selectors in affected flow tests |
| Feature removed | Delete corresponding flow test |
| Response envelope or data shape change | Update all API assertions that reference the changed shape |

## Test Quality Standards

- **Test outcomes, not elements.** Verify data persists via API, not just that a button is visible.
- **Walk the full path.** Start at a known entry point (dashboard, login), end at a verifiable result.
- **Monitor for errors.** Every flow test must check for 4xx/5xx responses during the flow.
- **Use a `@smoke` tag** (or your project's equivalent) for one critical test per feature area — these are the tests that run on every push.

## Recommended Flow Test Layout

```
e2e/
  flows/                    Full user journey tests, one spec per feature area
  flow-helpers.ts           Shared API validation, error monitoring, wizard helpers
  helpers.ts                Basic navigation helpers (login, role switching)
  fixtures/                 Reusable test data
```

Adapt to your stack (Playwright, Cypress, etc.) — the structure is the point, not the framework.

## Anti-Patterns (Never Do)

- Writing a feature without considering its test coverage
- Fixing a bug without adding a regression test
- Leaving dead/obsolete tests in the suite
- Writing tests that only check "is this element visible"
- Assuming existing tests cover a new code path without verifying
