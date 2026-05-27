# WCAG AA Contrast — Mandatory Floor

All user-facing text and meaningful UI affordances on the Uplift platform
**must meet WCAG AA contrast ratios** at minimum:

| Element | Min ratio | Notes |
|---|---|---|
| Body text (< 18pt regular / < 14pt bold) | **4.5 : 1** | Default for paragraphs, labels, captions, table cells |
| Large text (≥ 18pt regular / ≥ 14pt bold) | **3 : 1** | Headings, card values, hero copy |
| UI components & graphical objects | **3 : 1** | Icons that carry meaning, focus rings, form borders, accent strips |
| Inactive / disabled UI | No floor | But should still be distinguishable from active |

We treat AAA as aspirational, not required. We do **not** ship anything below AA.

## Why this rule exists

A previous palette shift introduced `--accent-primary: #E8A343` (warm amber).
On cream `#FDF9F3` it tested at **2.4 : 1** — below AA — and read "muted /
washed out" against the deeper teals on the same screens. We caught this only
in a screenshot review. Codifying the floor prevents the same class of issue.

## When this rule applies

**Every time** a color combination is introduced or modified, including but
not limited to:

- Adding or changing a CSS token in `index.css` (`:root` or `.dark` blocks)
- Picking a new accent / state / persona token value
- Inline `text-X` on `bg-Y` Tailwind class pairs in a component
- Brand gradient text (the headline-on-gradient pairing must still pass)
- Disabled / hover / active states (yes, including hover — they are read)
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
- **Darken / lighten the token** (preferred) — change the value in
  `index.css` so every component using the token gets the fix at once.
- **Pick a different token** — sometimes the right move is `text-ink-soft`
  instead of `text-accent` for body copy on a tinted background.
- **Do not** add bespoke `!important` overrides per-component to hit AA.
  That hides the underlying token problem and creates drift.

## Tokens that have known contrast risk on cream

These tokens are designed for **graphical objects, not body text** because
they sit close to the AA floor on cream. If you find yourself using them
for paragraph text or small labels, switch to a darker token:

| Token | Use for | Don't use for |
|---|---|---|
| `--accent-primary` | Buttons (with `--accent-on-primary` text), top accent strips, icon fills, focus rings | Body text on cream — use `--text-link` (#B8721A) instead |
| `--persona-solo` (`#E8A343`) | Persona pills, illustration accents | Standalone text on cream |
| `--state-warning-fg` | Warning text — already darkened to amber-700 for AA | n/a |

## Tokens designed for AA-safe text on cream

| Token | Hex | Ratio on cream |
|---|---|---|
| `--text-primary` (charcoal-800) | `#2C2420` | 14.8 : 1 |
| `--text-secondary` (warm-gray-500) | `#6E6459` | 5.4 : 1 |
| `--text-muted` (warm-gray-400) | `#908578` | 3.6 : 1 — **large text only** |
| `--text-link` (amber-600) | `#B8721A` | 4.7 : 1 |
| `--state-success-fg` (emerald-700) | `#047857` | 4.6 : 1 |
| `--state-info-fg` (deep-teal-500) | `#2D5957` | 7.1 : 1 |
| `--state-danger-fg` (terracotta-700) | `#643626` | 8.2 : 1 |

## Reviewer checklist

When reviewing a PR that touches colors:

- [ ] Every new token value tested at AA against the surface(s) it lands on
- [ ] Any `text-{accent|persona-*}` usage on cream/charcoal verified at AA
- [ ] Dark-mode counterpart also verified (same color often shifts pass↔fail)
- [ ] If the change tightened contrast in one mode, confirm it didn't loosen
      it in the other
- [ ] No bespoke per-component contrast overrides (fix the token instead)

## When AA is genuinely impossible

If a design genuinely requires a sub-AA combination (e.g., decorative
illustration text where the visual weight is part of the brand), it must be:

- **Non-load-bearing** — the user can complete the task without reading it
- **Documented** — comment in the code naming the deliberate exception
- **Surfaced to Tommy** — flag the trade-off; don't silently ship it

Default answer is still: pick a token that meets AA.
