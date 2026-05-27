# Proof of Work — Mandatory Verification Before Claiming Done

Every feature, bug fix, or behavioral change MUST be actively verified before being reported as complete. "Active verification" means exercising the actual user-facing path or API and observing the expected outcome — NOT "the code compiles" or "type checks pass."

## Required output format

Every coding turn ends with this section in your final message:

```
Proof of Work:
- What changed: <one-line summary>
- How I verified: <specific steps — pages visited, curls run, tests run, screenshots>
- What I observed: <observed outcomes — DB row id, response shape, test pass>
- Not verified: <gaps and why — or "none">
```

For trivial changes (typo, comment, dead-code removal, memory/plan file edit):

```
Proof of Work: trivial — <reason>
```

A Stop hook (`~/.claude/hooks/proof-stop-hook.sh`) enforces this: if files were edited in the current turn and the final message lacks "Proof of Work:", the turn is blocked.

## What counts as proof

| Change type | Verification |
|---|---|
| **UI feature/fix** | Run dev server; drive the new path with Playwright or browser; assert DOM + check console + check 4xx/5xx |
| **Backend route** | curl with realistic input; verify status + shape; query DB to confirm side effect; one error case |
| **Bug fix** | Reproduce broken behavior first; apply fix; re-run same flow; add regression test; run it |
| **Refactor** (no behavior change) | Run smoke suite (`npm run test:e2e:smoke`) |
| **Schema change** | Apply migration on staging DB; verify with `\d`; exercise dependent route |
| **Trivial** (typo, comment, dead code, memory/plan file) | Visual diff or short-form proof |

Use the `/proof` skill for the structured protocol.

## What does NOT count as proof

- "Type check passed" / "It compiles" — never proof
- "The unit tests pass" — only if a unit test exercises this exact path
- "I read the code and it looks right" — that's review, not verification
- Skipping the "Not verified:" line — silent gaps are the actual problem

## Why this rule exists

Tommy's recurring experience: "I tested the feature for the first time and the FIRST thing I tried was a bug." The cause: features get marked done without active verification. The fix: make proof a non-skippable structured output. The "Not verified:" line surfaces gaps Tommy would otherwise discover by stumbling.

This rule supersedes and unifies the prior memory rules (`feedback_post_feature_validation`, `feedback_proactive_bug_hunting`, `feedback_e2e_test_philosophy`, `feedback_evolve_tests_with_features`) by giving them a single enforceable output contract.

## Exemptions (no proof required)

- Pure read/exploration turns (no Edit/Write/MultiEdit/NotebookEdit tool calls in the current turn) — hook auto-passes
- Conversations that didn't modify files

Everything else needs proof. When in doubt, write the short form.
