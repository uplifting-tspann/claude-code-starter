---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---

# Overlay Viewport Safety — Floating Layers Must Never Be Clipped or Off-Screen

## Core Rule

Every **floating layer** — a date-picker calendar, dropdown/`Listbox` panel,
popover, context menu, autocomplete list, tooltip, combobox, or any element
positioned relative to a trigger — MUST satisfy **both**:

1. **Escape overflow clipping.** Render in a portal to `document.body` (or a
   dedicated overlay root) so no ancestor with `overflow: hidden/auto/scroll`
   (slideouts, modals, scrolling cards, tables) can clip it.
2. **Stay inside the viewport.** Position it so it is **always fully
   visible**: flip to the other side of the trigger when there isn't room,
   and clamp to the viewport edges so it never renders off the top, bottom,
   left, or right.

A portal alone is **not** enough. A portaled, `position: fixed` popover that
always opens downward from the trigger is still broken when the trigger sits
near the bottom of the screen — it renders below the fold and is
unreachable. The two halves are independent and both mandatory.

## The two failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Popover cut off by a card/slideout/modal edge; only part shows | Rendered inline inside an `overflow`-clipping ancestor | Portal it out to `document.body` |
| Popover opens off the bottom (or right) of the screen; can't scroll to it | Portaled + `fixed` but positioned only one way (always below/right), no flip, no clamp | Flip when insufficient room + clamp to viewport |

The second is the sneaky one: it looks fine in every dev test because the
dev's trigger is usually mid-screen. It only breaks when a real form puts
the field near a viewport edge (a date field above a sticky footer, a
dropdown at the bottom of a long page).

## Required positioning behavior

When you compute a floating layer's position from the trigger's
`getBoundingClientRect()`:

- **Preferred side, with flip.** Prefer the natural side (below for a
  calendar/menu, right for a submenu). If the layer's height/width doesn't
  fit on that side **and** the opposite side has more room, flip to it.
- **Clamp to the viewport.** After choosing a side, clamp the final top/left
  so the layer stays within `[margin, viewport − size − margin]` on both
  axes. This guarantees full visibility even when neither side fully fits
  (viewport shorter than the layer) — the layer's primary controls stay
  reachable.
- **Reposition on scroll + resize.** Recompute on `scroll` (capture: true,
  so it tracks inside scrollable containers) and `resize`, then remove the
  listeners on close.
- **Measure when you can, estimate when you can't.** Use the mounted
  layer's real `offsetHeight/offsetWidth` once available; on the first
  paint fall back to a safe over-estimate (over-estimating only errs toward
  keeping it on-screen).

## Use a shared component — don't hand-roll

- **Dropdowns / selects:** a library that anchors and flips for you (e.g.
  Headless UI's `Listbox`/`Menu`), never a bare absolutely-positioned
  `<ul>`.
- **Date fields:** a single shared `DatePicker` component — never a native
  `<input type="date">`, and never a second bespoke calendar that
  reintroduces the clipping/off-screen bug the shared one already solved.
- **New bespoke popover:** if there is genuinely no shared component to
  reuse, it MUST implement portal + flip + clamp itself. A new floating
  layer that only opens one direction is not done.

## Checklist for any floating layer

- [ ] Rendered in a portal (or via a library that portals) — survives an
      `overflow: hidden` ancestor
- [ ] Positioned with flip when the preferred side lacks room
- [ ] Final position clamped to the viewport on both axes
- [ ] Repositions on scroll (capture) + resize; listeners cleaned up on close
- [ ] Verified with the trigger **near the bottom and right edges** of the
      viewport, not just mid-screen
- [ ] Closes on outside click / Escape; focus returns to the trigger

## Anti-Patterns (never do)

- A portaled `fixed` popover that always opens downward with no flip/clamp
  — breaks for any trigger near the bottom of the screen.
- Relying on a portal alone and assuming "fixed position = always visible."
- Hand-rolling an absolutely-positioned dropdown inside a scrolling card
  instead of portaling it.
- Testing a new date/select/popover only with the field mid-screen and
  calling it done.
- Adding a second calendar/dropdown component that re-solves positioning
  badly instead of reusing the shared one.

## Why This Rule Exists

A product's form builder put a date field just above a sticky action
footer. The shared date-picker component already portaled its calendar to
`document.body` (escaping overflow), but its repositioning logic only
handled horizontal overflow — it always placed the calendar at `trigger.bottom
+ 4` with no vertical flip or clamp. With the field near the bottom of the
viewport, the calendar rendered below the fold and was completely
unreachable — a date field that could not be used at all. The field looked
fine everywhere it sat mid-page, so it shipped. The fix (flip-above +
viewport clamp) is one layout effect; codifying it means every floating
layer is checked for the edge-of-viewport case at design time instead of a
user discovering an unusable form control.
