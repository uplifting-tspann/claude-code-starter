---
name: code-cleanup
description: Run a 7-track code cleanup pass on a project — dedup, type consolidation, dead code, circular deps, type strengthening, error handling, deprecated/AI slop. Scan first, fix only high-confidence items. Reads ~/.claude/projects-config.json for paths and verify commands.
disable-model-invocation: true
---

# code-cleanup

A structured 7-track cleanup pass. Each track scans first, presents
findings, and only implements fixes after user review. Per-batch verify
prevents introducing new failures.

## Arguments

- No args → run all 7 tracks against the current working directory
- Project name → `/code-cleanup my-app` — target a specific project from
  `projects-config.json`
- Track name → `/code-cleanup type-strengthening` — run one track only
- `scan` → `/code-cleanup scan` — scan all tracks without implementing fixes

Track names: `dedup`, `types`, `dead-code`, `circular`,
`type-strengthening`, `error-handling`, `slop`.

## Step 0 — Resolve target + verify commands

If the user passed a project name, look it up in
`projects-config.json`. Read:

- `project.path` — root of the project
- `project.frontend.path` — frontend source dir (if any)
- `project.backend.path` — backend source dir (if any)
- `project.frontend.typecheck_command` — used to verify TS changes
- `project.backend.typecheck_command` — used to verify Python changes (or
  fall back to an import-check loop if absent)
- `project.frontend.lint_command`, `project.backend.lint_command` —
  optional, used as additional verify steps

If the user didn't pass a project name, fall back to `pwd` and try to
match against `projects[].path`. If no match, ask which project they
mean.

If the project has both frontend and backend, ask which to target (or
both sequentially).

Language detect (if not obvious from the path):
- `tsconfig.json` present → TypeScript frontend
- `routes/*.py` or `*.py` files present → Python backend

## Step 1 — Deduplication

**Goal:** Find repeated logic. Consolidate where it genuinely simplifies.

### Scan

**TypeScript** — exported functions with identical names across files:

```bash
grep -rn "export \(function\|const\|class\)" --include="*.ts" --include="*.tsx" <target> | \
  awk -F: '{print $1, $3}' | sort | uniq -d
```

Also: service functions that hit identical API endpoints.

**Python** — function definitions with matching signatures:

```bash
grep -rn "^def \|^async def " --include="*.py" <target>/routes/ <target>/services/ | \
  awk -F: '{split($3, a, "("); print a[1]}' | sort | uniq -d
```

### Present findings

| File A | File B | Function/Pattern | Similarity | Notes |
|--------|--------|------------------|------------|-------|

### Rules

- Consolidate within the same project only. Cross-project duplication
  (e.g., a CRM connector shared between two backends) → **flag, do NOT
  consolidate**. Recommend a shared package instead.
- Extract shared logic to a utility; update both call sites.
- Do NOT merge code that looks similar but serves different domain purposes.

### Verify

- TypeScript: run `project.frontend.typecheck_command`
- Python: import-check on affected modules

---

## Step 2 — Type Consolidation (TypeScript only)

**Goal:** Find type definitions scattered across files. Merge duplicates
into a single source of truth.

### Scan

```bash
grep -rn "^export \(interface\|type\) " --include="*.ts" --include="*.tsx" <target>
```

Group by name. Flag:
- Same type name defined in 2+ files
- Types in page/component files used by 2+ other files (move to `/types/`)
- Types that have drifted out of sync (same name, different fields)

### Present findings

| Type Name | Locations | Used By | Drifted? | Action |
|-----------|-----------|---------|----------|--------|

### Rules

- Move types to `/types/<domain>.ts` only when used by 2+ files.
- Single-use types stay inline.
- Never rename types — only relocate.
- Update all import paths after moving.
- Respect intentional sync patterns (look for `// KEEP IN SYNC` comments).

### Verify

- Run `project.frontend.typecheck_command` after each batch.

---

## Step 3 — Dead Code Removal

**Goal:** Find unused exports, unreferenced functions, orphaned files.
Remove only what is **confirmed dead**.

### Scan

**TypeScript** — for each exported symbol, search for imports/references:

```bash
grep -rn "^export " --include="*.ts" --include="*.tsx" <target> | head -200
grep -rn "import.*<symbol_name>" --include="*.ts" --include="*.tsx" <target>
```

**Python** — for each `def`, check whether it's:
- Decorated with `@bp.route`, `@app.route`, etc. (framework-invoked)
- Called from another function
- Explicitly marked `_deprecated_` or `DEPRECATED`

### Present findings

| Symbol | File:Line | References | Confidence | Safe to Remove? |
|--------|-----------|------------|------------|-----------------|

### SAFETY RULES (critical)

**NEVER remove:**
- Functions decorated with framework decorators (`@bp.route`, `@app.route`, etc.)
- React components that might be lazy-loaded via `React.lazy()` or dynamic `import()`
- Functions starting with `test_` or `Test`
- Python dunder methods (`__init__`, `__str__`, etc.)
- Anything in `__init__.py` files (may be re-exported)
- Config objects or constants that might be read by bundler/framework

**Safe to remove:**
- Functions explicitly prefixed `_deprecated_` or commented `DEPRECATED` with zero call sites
- Commented-out code blocks (>5 lines of former logic, since git history preserves)
- Unused locals/imports within a function

### Rules

- Only remove items with **zero references** across the entire project.
- For each removal, do a final `grep` for the symbol name to triple-check.
- Remove in small batches (5-10 items), verify after each batch.

### Verify

- TypeScript: `project.frontend.typecheck_command`
- Python: import-check on affected modules

---

## Step 4 — Circular Dependencies (TypeScript only)

**Goal:** Identify circular imports that affect maintainability or correctness.

### Scan

```bash
cd <frontend_root> && npx madge --circular --extensions ts,tsx src/ 2>/dev/null
```

If `madge` is unavailable, manually trace bidirectional imports via
grep on `from '..` patterns.

### Present findings

| Cycle | Files Involved | Impact | Suggested Break Point |
|-------|----------------|--------|----------------------|

### Rules

- Extract shared types/constants into a third file that both sides import.
- Do NOT introduce new abstraction layers just to break a cycle.
- Late imports (inside functions) are acceptable as a last resort — flag as tech debt.
- If no cycles, report clean and move on.

### Verify

- `project.frontend.typecheck_command`
- Re-run madge to confirm cycle is broken.

---

## Step 5 — Type Strengthening (TypeScript only)

**Goal:** Replace `any`, `unknown`, and weak placeholder types with proper types.

### Scan

```bash
grep -rn ": any" --include="*.ts" --include="*.tsx" <target>
grep -rn "as any" --include="*.ts" --include="*.tsx" <target>
```

For each, read context. Categorize:
- **(a) API response** — needs a proper interface
- **(b) Event handler** — use `React.ChangeEvent<HTMLInputElement>` etc.
- **(c) Catch variable** — `catch (e: any)` → `catch (e: unknown)` with type narrowing
- **(d) Legitimate** — third-party interop, complex generics
- **(e) Function parameter** — determine actual usage

### Present findings

| File:Line | Current | Category | Suggested Type | Confidence |
|-----------|---------|----------|---------------|------------|

### Rules

- Fix only **high-confidence** items where the correct type is obvious.
- For (a): create the interface in `/types/`, or use existing types.
- For (b): use the specific React event type.
- For (c): replace with `unknown` + `if (e instanceof Error)` narrowing.
- For (d): leave as-is; add `// eslint-disable-next-line` if needed.
- Fix in batches of 5-10; verify after each.

### Verify

- `project.frontend.typecheck_command` after every batch.

---

## Step 6 — Error Handling Cleanup

**Goal:** Find try/catch blocks silently swallowing errors. Remove
silent fallbacks. Keep real boundary handling.

### Scan

**TypeScript:**

```bash
# Silent catches
grep -rn "catch.*{" --include="*.ts" --include="*.tsx" -A2 <target> | grep -E "(ignore|\/\/ ?$|^\s*\})"

# Empty catches
grep -rn "catch\s*{" --include="*.ts" --include="*.tsx" <target>
```

**Python:**

```bash
# Bare except
grep -rn "except:" --include="*.py" <target>

# Except with pass
grep -rn "except.*:" --include="*.py" -A1 <target> | grep -B1 "pass"
```

### Present findings

| File:Line | Current | Context | Risk | Suggested Fix |
|-----------|---------|---------|------|---------------|

### Rules

**Fix these:**
- `catch { /* ignore */ }` → add `console.error('Context:', err)` at minimum.
- `catch { }` (empty) → log or remove the try/catch entirely if the operation should propagate.
- `except:` (bare) → `except Exception as e:` with `logger.error(f"Context: {e}", exc_info=True)`.
- `except Exception: pass` → add `logger.warning()` or `logger.error()`.

**Keep these (real boundaries):**
- Top-level catches in route handlers that return proper error responses.
- Catches that do cleanup (close connections) before re-raising.
- React component error boundaries.
- try/except around optional operations with a clear fallback (cache miss → DB).

**Gray area — ask the user:**
- `catch { setError(null) }` — silently hides the error but resets state.
- `except Exception: return default_value` — silent fallback masking root cause.

### Verify

- `project.frontend.typecheck_command` / backend import-check.

---

## Step 7 — Deprecated Code & AI Slop

**Goal:** Find legacy code, deprecated functions, AI-generated artifacts.
Remove what's clearly obsolete.

### Scan

**Deprecated/legacy markers:**

```bash
grep -rn "DEPRECATED\|deprecated\|OBSOLETE\|obsolete\|LEGACY\|legacy" --include="*.ts" --include="*.tsx" --include="*.py" <target>
```

**TODO/FIXME** (report only, do not remove):

```bash
grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.tsx" --include="*.py" <target>
```

**AI narrative comments** (comments that narrate edit history):

```bash
grep -rn "Previously\|Changed from\|Updated to\|Added for\|Removed the\|Used to be\|Was originally\|Refactored from" --include="*.ts" --include="*.tsx" --include="*.py" <target>
```

**Placeholder stubs:**

```bash
# Python
grep -rn "def.*:" --include="*.py" -A2 <target> | grep -B1 "pass$\|return None$\|return {}$"

# TypeScript
grep -rn "throw new Error.*not implemented\|// stub\|// placeholder" --include="*.ts" --include="*.tsx" <target>
```

### Present findings

| File:Line | Type | Content | Safe to Remove? |
|-----------|------|---------|-----------------|

Types: `deprecated-function`, `deprecated-comment`, `ai-narration`, `stub`, `todo`.

### Rules

- **Deprecated functions:** remove only if zero call sites (verify with grep).
- **AI narration comments:** remove if they restate what the code does or narrate edit history. Rewrite if intent is worth preserving.
- **Stubs:** remove only if not part of an interface/abstract contract.
- **TODO/FIXME:** report but **do NOT remove** — they track real work.
- **Commented-out code blocks** (>5 lines): remove — git history preserves the old version.

### Verify

- `project.frontend.typecheck_command` / backend import-check.

---

## Final verification

Run all configured verify commands once at the end:

- `project.frontend.lint_command` (if set)
- `project.frontend.typecheck_command` (if set)
- `project.backend.lint_command` (if set)
- `project.backend.typecheck_command` (if set)

If any verify fails, revert the last batch and report the failure.

## Summary report

| Track | Findings | Fixed | Skipped | Reason |
|-------|----------|-------|---------|--------|
| 1. Deduplication | — | — | — | — |
| 2. Type Consolidation | — | — | — | — |
| 3. Dead Code | — | — | — | — |
| 4. Circular Deps | — | — | — | — |
| 5. Type Strengthening | — | — | — | — |
| 6. Error Handling | — | — | — | — |
| 7. Deprecated/Slop | — | — | — | — |

Ask: "Want me to go deeper on any skipped items?"

## Anti-patterns (never do)

- Skipping the per-batch verify. The whole point is small steps that revert easily.
- Removing anything based on a single grep. Triple-check before deleting.
- Consolidating across projects. Suggest a shared package instead.
- "Fixing" gray-area items without asking the user.
