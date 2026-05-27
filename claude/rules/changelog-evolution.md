# Changelog — Mandatory Evaluation Rule

> **Applicability:** This rule only applies if your project publishes a customer-facing changelog (a release notes page, an email update series, an in-app "What's New" panel, etc.). If you don't publish one, delete this rule. The rest assumes you do.

## Core Principle

Your customer-facing changelog is a living artifact that MUST evolve with every customer-visible change. This rule does NOT require writing the entry in the same turn — entries can be batched (e.g., via a `/whats-new` style skill that sweeps `git log` since the last published entry). This rule's job is to make the evaluation mandatory and the reporting non-skippable, so changelog-worthy work never gets buried.

## After Every Feature, Bug Fix, or Behavioral Change

Before considering any work complete, answer these questions:

1. **Is this change customer-visible?** A user of your product would observe a new capability, a changed workflow, a fixed bug they were aware of, a new integration, or a security-relevant shift. If yes → candidate.
2. **If yes, what `type` is it?** Pick from your changelog's vocabulary. A common set: `feature`, `improvement`, `fix`, `integration`, `security`.
3. **If no, why not?** Admin-only, refactor, internal tooling, test-only, docs-only, copy tweak with no behavior change, alignment fix, etc.

The writing happens later in batch — but the evaluation happens now.

## Triggers → Required Action

| Change Type | Required Action |
|-------------|-----------------|
| **New customer-visible feature** | Flag as `feature` candidate with proposed title. |
| **Meaningful UX/quality lift to an existing surface** | Flag as `improvement` candidate. |
| **Bug fix a user would have been aware of** | Flag as `fix` candidate. "Aware of" = they could have hit it in the product, complained about it, or filed a ticket. Silent backend bugs users never noticed → not applicable. |
| **Third-party integration work shipped** | Flag as `integration` candidate. |
| **User-facing or compliance-relevant security change** | Flag as `security` candidate. |
| **Admin-only work, internal tooling, refactor, test/CI, copy fix, alignment fix** | "Not applicable" with one-line reason. |

## Where the Changelog Lives (fill in for your project)

- **Source of truth**: `[file path, DB table, or CMS]`
- **Public surface(s)**: `[URLs]`
- **Writer**: ideally a single dedicated skill or workflow — never edit the source of truth by hand. If you have a `/whats-new` style skill, this rule pairs with it.

## Always Report a `Changelog:` Section to the User

After any coding turn that materially modified files, include a short **Changelog** section in the end-of-turn summary. The user must always know whether the work is changelog-worthy so they can run the batch process at the appropriate cadence — and so they can override your judgment.

Format:

```
Changelog:
- Candidate (<type>): "<one-line proposed title in peer voice, no marketing punch>"
- Not applicable: <one-line reason, e.g. "alignment fix, no behavior change">
```

Rules:

- Always include this section when files were modified, even if the answer is "not applicable."
- One line per logical change. If a turn shipped multiple distinct customer-visible changes, list each as its own `Candidate (…)` line.
- Title must follow plain-English, peer voice. Sentence case. No marketing words. If you catch yourself writing "Unlock seamless X" or "Revolutionize your Y", rewrite.
- Don't draft the full description — that's the batch process's job, where customer voice gets concentrated review. The title is enough.
- Omit only when no files were modified (pure read/exploration turn) or when the change is so trivial it falls under proof-of-work's "trivial" exemption (typo, comment, memory file edit).

## When to Be Liberal vs. Strict with "Candidate"

**Lean toward candidate** when:
- New page, new tab, new card, new wizard step, new field on a form
- New API surface that users or integrators would notice
- Pricing/billing change visible to users
- Default behavior change (even small ones — "we now default X to Y" is changelog-worthy)
- Integration with a new third-party service
- New permission, role, or access control surface users interact with

**Lean toward not-applicable** when:
- Pure refactor with no behavior change
- Test-only or CI-only changes
- Internal admin tooling not exposed to users
- Copy-only fixes that don't change product behavior
- Bug fixes for issues users never encountered (silent bugs)
- Performance improvements with no observable user-facing shift (unless they fix a known slow surface users had complained about — then `improvement`)
- Schema migrations with no API/UI impact
- Documentation updates

When genuinely uncertain, **default to candidate** with a note ("not sure if this rises to user-visible"). The user can downgrade it at batch time. Burying a real candidate is worse than over-flagging.

## Interaction with Other Rules

- **Help article evolution**: related but distinct. Help articles cover *how to use* a feature; changelog entries announce *that the feature shipped*. A feature may warrant both, one, or neither. Report each section independently.
- **Proof of Work**: the `Changelog:` section is part of the end-of-turn summary, not a replacement for the `Proof of Work:` section. Include both.
- **Commit discipline**: this rule does NOT trigger an automatic changelog publish. The user decides when to batch — typically after a few related commits land or before a public announcement.

## Anti-Patterns (Never Do)

- Shipping a customer-visible feature without flagging a candidate in the end-of-turn summary
- Auto-publishing changelog entries without the user's approval — batch + approval gate is the point
- Editing the changelog source of truth by hand when a dedicated skill exists for it
- Drafting marketing-voice candidate titles ("Revolutionize your workflow with smarter templates") — peer voice only
- Skipping the `Changelog:` section because "nothing changelog-worthy shipped" — say "Not applicable — <reason>" explicitly so the decision is auditable

## Why This Matters

The changelog is one of the most direct signals users have that the product is alive and improving. When customer-visible work ships and the changelog doesn't reflect it for weeks, users stop trusting the page — which makes the next launch announcement land softer than it should. This rule keeps every change consciously evaluated at ship time so the batch sweeps catch what matters.
