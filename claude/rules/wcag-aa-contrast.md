# WCAG AA Contrast — Mandatory Floor

All user-facing text and meaningful UI affordances **must meet WCAG AA contrast ratios** at minimum:

| Element | Min ratio | Notes |
|---|---|---|
| Body text (< 18pt regular / < 14pt bold) | **4.5 : 1** | Default for paragraphs, labels, captions, table cells |
| Large text (≥ 18pt regular / ≥ 14pt bold) | **3 : 1** | Headings, card values, hero copy |
| UI components & graphical objects | **3 : 1** | Icons that carry meaning, focus rings, form borders, accent strips |
| Inactive / disabled UI | No floor | But should still be distinguishable from active |

Treat AAA as aspirational, not required. Do **not** ship anything below AA.

## Why this rule exists

A palette token can look fine in isolation and fail when it lands on a real surface. A representative example: an amber accent like `#E8A343` reads "warm and inviting" on its own, but on a cream `#FDF9F3` background tests at **2.4 : 1** — well below AA — and reads "muted / washed out" against deeper neighboring colors. Mistakes like this typically get caught only in a screenshot review. Codifying the floor prevents the same class of issue.

## When this rule applies

**Every time** a color combination is introduced or modified, including but
not limited to:

- Adding or changing a CSS token (`:root` or `.dark` blocks)
- Picking a new accent / state token value
- Inline `text-X` on `bg-Y` Tailwind class pairs in a component
- Brand gradient text (the headline-on-gradient pairing must still pass)
- Disabled / hover / active states (yes, including hover — they get read)
- Email templates, PDF output, exported documents

## How to verify

**Before shipping any color change**, check the foreground / background pair
against AA using one of:

1. **Chrome / Edge DevTools** — inspect element, click the swatch in the
   Styles panel; the contrast ratio is shown with a pass/fail badge.
2. **WebAIM Contrast Checker** — `https://webaim.org/resources/contrastchecker/` — paste hex values.
3. **`@axe-core/cli`** — for automated runs in CI.
4. **Computed math** — if working from token RGB tuples, plug them into a
   relative-luminance calculator. Acceptable for one-off design decisions.

If the pair fails:
- **Darken / lighten the token** (preferred) — change the value at the token
  level so every component using the token gets the fix at once.
- **Pick a different token** — sometimes the right move is a darker
  "ink-soft" token instead of an accent token for body copy on a tinted
  background.
- **Do not** add bespoke `!important` overrides per-component to hit AA.
  That hides the underlying token problem and creates drift.

## Pattern: known-risk vs. AA-safe tokens

Document for each surface (e.g., your light background, your dark background)
which tokens are AA-safe for text and which are intended only for graphical
use. Example structure your token system should adopt:

| Token role | Use for | Don't use for |
|---|---|---|
| Accent (primary) | Buttons (with explicit on-accent text token), accent strips, icon fills, focus rings | Body text on the light surface — use a darker link token instead |
| Persona / decorative | Pills, illustration accents | Standalone text on the light surface |
| State (warning / success / error / info) — `-fg` variant | Status text (these should already be darkened to pass AA) | n/a |
| Text (primary / secondary / muted) | Body and label text | — |

The exact tokens and hex values are your project's call. The *categorization* is the rule: every token has a role, and the role names which surfaces it's AA-safe on.

## Reviewer checklist

When reviewing a PR that touches colors:

- [ ] Every new token value tested at AA against the surface(s) it lands on
- [ ] Any decorative-token usage on body text verified at AA
- [ ] Dark-mode counterpart also verified (same color often shifts pass↔fail)
- [ ] If the change tightened contrast in one mode, confirm it didn't loosen
      it in the other
- [ ] No bespoke per-component contrast overrides (fix the token instead)

## When AA is genuinely impossible

If a design genuinely requires a sub-AA combination (e.g., decorative
illustration text where the visual weight is part of the brand), it must be:

- **Non-load-bearing** — the user can complete the task without reading it
- **Documented** — comment in the code naming the deliberate exception
- **Flagged to the user** — surface the trade-off; don't silently ship it

Default answer is still: pick a token that meets AA.
