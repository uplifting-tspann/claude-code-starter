# Changelog — Mandatory Evaluation Rule

## Core Principle

The Bridge customer-facing changelog (rendered at
`docs.upliftingpartners.com/changelog` and
`help.upliftingpartners.com/changelog`) is a living artifact that MUST
evolve with every customer-visible Bridge change. This rule does NOT
require writing the entry in the same turn — entries are batched via
the `/whats-new` skill which sweeps `git log` since the last published
entry. This rule's job is to make the evaluation mandatory and the
reporting non-skippable, so changelog-worthy work never gets buried.

## After Every Feature, Bug Fix, or Behavioral Change

Before considering any work complete, answer these questions:

1. **Is this change customer-visible in Bridge?** A partner using
   `docs.upliftingpartners.com` (or the partner portal) would observe a
   new capability, a changed workflow, a fixed bug they were aware of,
   a new integration, or a security-relevant shift. If yes → candidate.
2. **If yes, what `type` is it?** `feature`, `improvement`, `fix`,
   `integration`, or `security`. Pick the one that best matches the
   `/whats-new` schema (see [whats-new/SKILL.md](/Users/tunky-mini/.claude/skills/whats-new/SKILL.md) §5).
3. **If no, why not?** Admin-only, refactor, internal tooling, test-only,
   docs-only, copy tweak with no behavior change, alignment fix, etc.

The writing happens later in batch — but the evaluation happens now.

## Triggers → Required Action

| Change Type | Required Action |
|-------------|-----------------|
| **New customer-visible Bridge feature** | Flag as `feature` candidate with proposed title. |
| **Meaningful UX/quality lift to an existing Bridge surface** | Flag as `improvement` candidate. |
| **Bug fix a partner would have been aware of** | Flag as `fix` candidate. "Aware of" = they could have hit it in the product, complained about it, or filed a ticket. Silent backend bugs partners never noticed → not applicable. |
| **Third-party integration work (CRM, QBO, Stripe, BoldSign, Resend, etc.) shipped** | Flag as `integration` candidate. |
| **User-facing or compliance-relevant security change** | Flag as `security` candidate. |
| **Admin-only Hub work, internal tooling, refactor, test/CI, copy fix, alignment fix** | "Not applicable" with one-line reason. |
| **Hub-only feature** | "Not applicable — Hub admin, not Bridge partner-facing." Note: changelog supports `area: 'Hub'`, but the `/whats-new` skill is Bridge-only today, so Hub entries are out of scope for this rule. |

## Where the Changelog Lives

- **Source of truth**: two byte-identical JSON files in the Help repo
  - `Help/frontend/src/data/changelog.json` — read by Help frontend
  - `Help/backend/data/changelog.json` — served by `GET /help/changelog`
- **Bridge surface**: `docs.upliftingpartners.com/changelog` (filters
  `area === 'Docs'`) — rendered by [Docs/GCP/frontend/src/pages/Changelog.tsx](/Users/tunky-mini/projects/docs/GCP/frontend/src/pages/Changelog.tsx)
- **Help surface**: `help.upliftingpartners.com/changelog` (full list)
- **Only writer**: the `/whats-new` skill at
  [~/.claude/skills/whats-new/SKILL.md](/Users/tunky-mini/.claude/skills/whats-new/SKILL.md). Never edit either JSON
  file by hand. The skill handles git scan, customer-voice drafting,
  user approval, prepend + commit, HubSpot HTML for the email send.

## Always Report a `Changelog:` Section to the User

After any coding turn that materially modified files, include a short
**Changelog** section in the end-of-turn summary. The user must always
know whether the work is changelog-worthy so they can run `/whats-new`
at the appropriate cadence — and so they can override your judgment.

Format:

```
Changelog:
- Candidate (<type>): "<one-line proposed title in peer voice, no marketing punch>"
- Not applicable: <one-line reason, e.g. "alignment fix, no behavior change">
```

Rules:

- Always include this section when files were modified, even if the
  answer is "not applicable."
- One line per logical change. If a turn shipped multiple distinct
  customer-visible changes, list each as its own `Candidate (…)` line.
- Title must follow the `/whats-new` voice rules (§5 of the skill):
  plain English, peer voice, sentence case, no marketing words. If you
  catch yourself writing "Unlock seamless X" or "Revolutionize your Y",
  rewrite.
- Don't draft the full `description` field — that's `/whats-new`'s job
  in batch where customer voice gets concentrated review. The title is
  enough.
- Omit only when no files were modified (pure read/exploration turn) or
  when the change is so trivial it falls under proof-of-work's "trivial"
  exemption (typo, comment, memory file edit).

## When to Be Liberal vs. Strict with "Candidate"

**Lean toward candidate** when:
- New page, new tab, new card, new wizard step, new field on a form
- New API surface that partners or integrators would notice
- Pricing/billing change visible to partners
- Default behavior change (even small ones — "we now default X to Y" is
  changelog-worthy)
- Integration with a new third-party service
- New permission, role, or access control surface partners interact with

**Lean toward not-applicable** when:
- Pure refactor with no behavior change
- Test-only or CI-only changes
- Internal admin tooling not exposed to partners
- Copy-only fixes that don't change product behavior
- Bug fixes for issues partners never encountered (silent bugs)
- Performance improvements with no observable user-facing shift (unless
  they fix a known slow surface partners had complained about — then
  `improvement`)
- Schema migrations with no API/UI impact
- Documentation updates

When genuinely uncertain, **default to candidate** with a note ("not
sure if this rises to partner-visible"). The user can downgrade it at
`/whats-new` time. Burying a real candidate is worse than over-flagging.

## Interaction with Other Rules

- **Help article evolution** (`~/.claude/rules/help-article-evolution.md`):
  related but distinct. Help articles cover *how to use* a feature;
  changelog entries announce *that the feature shipped*. A feature may
  warrant both, one, or neither. Report each section independently.
- **Proof of Work** (`~/.claude/rules/proof-of-work.md`): the
  `Changelog:` section is part of the end-of-turn summary, not a
  replacement for the `Proof of Work:` section. Include both.
- **Commit discipline** (`~/.claude/rules/commit-discipline.md`): this
  rule does NOT trigger an automatic `/whats-new` run. The user decides
  when to batch — typically after a few related commits land on staging
  or before a public announcement.
- **Messaging brief** (`~/.claude/rules/messaging-brief.md`): the
  candidate title is user-facing copy. Forbidden words still apply
  ("platform", "seamless", "unlock", etc.). If you wouldn't ship the
  title on a button, don't propose it as a candidate title.

## Anti-Patterns (Never Do)

- Shipping a customer-visible Bridge feature without flagging a
  candidate in the end-of-turn summary
- Auto-invoking `/whats-new` without the user asking — the skill is
  `disable-model-invocation: true` for a reason (batch + approval gate)
- Editing `changelog.json` directly — the skill is the only writer
- Drafting marketing-voice candidate titles ("Revolutionize your
  workflow with smarter templates") — peer voice only
- Treating Hub admin work as Bridge changelog material — Hub is for
  internal admin functions; Bridge is the partner product. The
  `/whats-new` skill scopes to `area: 'Docs'` only.
- Skipping the `Changelog:` section because "nothing changelog-worthy
  shipped" — say "Not applicable — <reason>" explicitly so the
  decision is auditable.

## Why This Matters

The changelog is one of the most direct signals partners have that the
product is alive and improving. When customer-visible work ships and
the changelog doesn't reflect it for weeks, partners stop trusting the
page — which makes the next launch announcement land softer than it
should. The `/whats-new` skill picks up everything from git anyway, but
only if it's actually run. This rule keeps every change consciously
evaluated at ship time so the batch sweeps catch what matters and the
user knows when to trigger them.
