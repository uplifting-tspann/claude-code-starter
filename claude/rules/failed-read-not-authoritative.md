---
paths:
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*.jsx"
  - "**/*.py"
---

# A Failed Read Must Never Render as a Genuine Empty/Zero Result

## Core Rule

When a fetch/query fails, the catch block's fallback state (`[]`, `0`,
`null`) must be **visibly distinguishable** from a genuine empty result —
never silently indistinguishable. Downstream code (a count, a summary
sentence, a rendered list) cannot tell the difference between "we checked
and there's nothing" and "we couldn't check" unless the failure carries its
own flag. Treating a failed read as the authoritative value publishes a
false claim to the user.

## The recurring shape

Several distinct components can independently reproduce the same bug:

- A component's `catch` sets `items = []` to stop the spinner; `[]` is
  truthy, so a downstream count effect publishes a fabricated `0` into page
  state that never re-checks.
- The SUCCESS branch can recreate the identical bug via a nullish-coalesce
  on a drifted response shape — `response.json() ?? []` silently
  substitutes an empty array for "couldn't parse," which has the same
  effect as swallowing an error. The bug doesn't only live in catch blocks.
- A backend service's failed sub-query can render as an affirmative claim
  ("no records found") when the honest answer is "the lookup failed" — a
  private-count failure rendering as a public `0`.
- A `catch` that sets `sections = []` can render an authoritative "nothing
  here" message alongside a live "Add" form on a FAILED load, inviting the
  user to create data the fetch never actually confirmed doesn't exist.

## How to apply

- Every fetch that feeds a **count, a summary sentence, or an
  existence/absence claim** needs a separate `error`/`loadFailed` boolean
  (or a tri-state `'loading' | 'error' | 'loaded'`) alongside its data
  state — not just a data array that happens to be empty either way.
- Gate the "authoritative" UI (a summary count, an affirmative "no X exist"
  message, an empty-state CTA) on `!error`, not just `!loading`.
- Applies to the SUCCESS branch too, not only `catch`: a `response.json() ??
  []` or `result.items || []` that silently substitutes empty for a
  malformed/unexpected response has the same effect as swallowing an error
  — the substitution itself needs a loud path (log it, flag it) if the
  shape didn't match expectations.
- If you extract a shared "collapsed summary card" component, gate it on
  error by construction — this is exactly the kind of "authoritative claim
  derived from data" this rule protects.

## Anti-patterns (never do)

- `catch (err) { setItems([]); }` with no error state — the empty array
  reads as ground truth to every consumer downstream.
- Trusting `?? []` / `|| []` to mean "no error happened" — it means "I got
  something falsy," which includes a parse failure or a shape mismatch.
- Rendering an "Add new X" / "Create your first Y" empty-state CTA without
  checking the load actually succeeded — inviting data entry on top of a
  failed read risks duplicating data that already exists.
