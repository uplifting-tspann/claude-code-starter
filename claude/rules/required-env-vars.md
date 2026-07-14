# Required Env Vars — Two-Pattern Fail-Loud Framework

> **Applicability:** This rule applies if your app reads runtime configuration
> from environment variables and deploys to a hosted runtime whose env config is
> managed separately from your source tree (a PaaS, a container platform, a
> serverless runtime). If all your config is committed and there is no
> deploy-time binding step, delete this rule.

Every required runtime configuration value (env var) that, if missing in the
deployed environment, would cause **silent** damage MUST use the two-pattern
framework below. Don't write
`os.getenv('SECURITY_RELEVANT_VAR', 'some-default')` at module level — that's
the exact bug class described in "Why this rule exists."

## Core Principle — both patterns, always together

For any required env var, apply BOTH:

1. **Pattern A — the deploy config is the source of truth.** Add the binding to
   your deploy/CI config (the file that declares the service's env vars and
   secret references). That file is the audit trail; a live binding that exists
   only because someone set it by hand can silently disappear on the next
   destructive deploy.

2. **Pattern B — code fails loud in the deployed runtime.** Use a
   `_require_runtime_env(name, local_default)` helper. When running in the
   deployed environment (detected via an env var the platform always sets — most
   hosted runtimes set one, e.g. a service-name variable), a missing value raises
   at **module import** with a standardized message naming the variable and the
   service. In local dev / tests (no such variable), it returns the safe local
   default.

Neither pattern alone is sufficient. Pattern A without B means a silent
regression survives the deploy. Pattern B without A means the binding has no
audit trail and can vanish on the next deploy. Apply both.

## When this rule applies

Classify each env var by impact-if-missing-in-production:

### 🔴 HIGH-RISK — apply both patterns immediately

Silent fallback compromises security or bricks a core integration:

- **Encryption / signing keys** (`ENCRYPTION_KEY`, `JWT_SECRET`). An empty
  fallback breaks all encrypted token storage / signed cookies — quietly.
- **OAuth client IDs and secrets.** An empty fallback fails the first OAuth
  attempt with the provider's opaque "invalid_client" — visible-but-confusing.
- **HMAC shared secrets between internal services.** A hardcoded dev-key
  fallback in source means anyone with repo read access has the "secret."
- **URL constants that route external traffic** (`FRONTEND_URL`, `API_BASE_URL`,
  …). A hardcoded prod-URL fallback silently leaks prod URLs into dev test
  emails, OAuth state, and callback redirects.
- **Environment-mode selectors** (`SANDBOX` vs `PRODUCTION`, `LIVE` vs `TEST`).
  See the incident below — this is the worst one, because nothing errors.

### 🟡 MEDIUM-RISK — Pattern B with a deliberate decision

Degrades but doesn't brick:

- **Provider API keys with a `None` fallback.** `None` causes a visible failure
  at the first API call. Apply Pattern B if the value is read at **module
  level** (so boot fails fast in production); leave function-local reads alone —
  they already fail visibly at first use.
- **Per-env URL variants with 1–2 consumers** (low blast radius).
- **Secrets that cascade through another required secret** — low priority, since
  the cascade already protects them (the dev fallback is unreachable if the
  parent secret is bound, which it is in prod).

### 🟢 LOW-RISK — leave alone

Operational defaults that don't affect security or external routing: timeouts,
model names, bucket names, feature flags, log levels, notification channel names.

## How to apply Pattern B (the helper)

Put the helper in one shared module (e.g. `utils/runtime_env.py`):

```python
import os

# Most hosted runtimes set at least one env var of their own. Pick one your
# platform ALWAYS sets and never sets locally.
IS_DEPLOYED = bool(os.getenv('<PLATFORM_SET_VAR>'))


def _require_runtime_env(name: str, local_default: str) -> str:
    value = os.getenv(name)
    if value:
        return value
    if IS_DEPLOYED:
        raise RuntimeError(
            f"Required env var {name} is not set in the deployed runtime. "
            f"Bind it in the deploy config and redeploy."
        )
    return local_default
```

Then use it for module-level constants — evaluated at import, so a missing value
crashes the boot instead of silently misbehaving for hours:

```python
from utils.runtime_env import _require_runtime_env

ENCRYPTION_KEY = _require_runtime_env('ENCRYPTION_KEY', '')
FRONTEND_URL = _require_runtime_env('FRONTEND_URL', 'http://localhost:5173')
```

For shared URL constants with many consumers, declare them **once** in
`runtime_env.py` itself and import from there:

```python
# utils/runtime_env.py
FRONTEND_URL = _require_runtime_env('FRONTEND_URL', 'http://localhost:5173')
DOCS_URL     = _require_runtime_env('DOCS_URL',     'http://localhost:5174')
API_BASE_URL = _require_runtime_env('API_BASE_URL', 'http://localhost:8080')
```

```python
# consumers
from utils.runtime_env import FRONTEND_URL, API_BASE_URL
```

This is what makes the "two conflicting defaults" bug (below) structurally
impossible.

## Picking the local default

The local default fires outside the deployed runtime (local dev, tests). It MUST
satisfy two properties:

1. **Safe-broken in dev.** A missing env var should produce obviously-broken
   behavior, never a silent leak of prod values. For URLs, use
   `http://localhost:<port>`. **Never use a prod URL as a "fallback"** — that is
   exactly the bug this rule eliminates.
2. **Importable in dev without setup.** Tests must be able to import the module
   without first setting the env var. Use `''` for non-URL secrets — they fail
   later, when the secret is actually used, which is fine for unit tests that
   mock the consumer.

## Deploy ordering — live-bind BEFORE shipping fail-loud code

If the env var is NOT currently bound on the target service, you MUST bind it
live **before** merging the fail-loud code. Otherwise the next deploy crashes
the service at module import.

1. Generate the secret value (or pick the literal value).
2. Create the secret in your secret store if needed.
3. Bind it to the live service **additively** — use your platform's
   *update*/*patch* flag, never the *replace-all* flag. (Example: an
   `--update-env-vars` style flag preserves existing vars; a `--set-env-vars`
   style flag wipes everything not listed. Know which is which for your
   platform before you type it.)
4. Verify by reading back the live service config.
5. **ONLY THEN** commit the deploy-config + code change.

For env vars that are already bound (verified live), skip steps 1–4 — the config
change just codifies existing reality, and the code change doesn't alter runtime
behavior.

## Pattern A — deploy config rules

Your deploy config likely offers several flag types. Know the difference:

- **Replace-all** (`--set-env-vars`-style) — **destructive**. Wipes every literal
  env var not in the list.
- **Additive** (`--update-env-vars`-style) — preserves existing vars.
- **Secret reference** (`--update-secrets`-style) — additive binding to a
  secret-store entry.

When adding a new required env var:

1. **Pick the right flag** based on whether the value is a literal (URL,
   hostname, scalar) or a secret-store reference.
2. **Add it to every environment's config** — prod, staging, and any other
   environment the service deploys to. Per-env values for per-env things (URLs,
   per-env OAuth apps); the same secret name only when the secret is genuinely
   shared.
3. **Same commit as the code change.** Pattern A and Pattern B ship together.
   Splitting them creates a window where the code expects a var the config
   doesn't bind.

A common naming convention for multi-env secrets: prod is `<secret-name>`,
non-prod is `<env>-<secret-name>` (`staging-<secret-name>`, `demo-<secret-name>`).

## Tests that override module-level constants — patch the attribute, not the env

The single most common breakage when adopting this pattern. The bug:

```python
# ❌ BROKEN — the env var was already read at import time
@patch.dict(os.environ, {'FRONTEND_URL': 'https://example.com'})
def test_thing(self):
    from services.email_templates import build_email
    # build_email still uses 'http://localhost:5173' (the import-time value)
```

When `services.email_templates` is imported, it runs
`from utils.runtime_env import FRONTEND_URL` — the constant is **captured at
import time**. `monkeypatch.setenv` / `@patch.dict(os.environ, …)` change the
environment but never re-evaluate the constant.

The correct pattern — patch the imported reference:

```python
# ✅ CORRECT
@patch('services.email_templates.FRONTEND_URL', 'https://example.com')
def test_thing(self):
    ...
```

```python
# ✅ CORRECT — monkeypatch
def test_thing(self, monkeypatch):
    monkeypatch.setattr('services.email_templates.FRONTEND_URL', 'https://example.com')
```

```python
# ✅ CORRECT — patch.object
def test_thing(self):
    with patch.object(some_client, 'API_BASE_URL', 'https://staging.example.com'):
        assert some_client.detect_environment() == 'staging'
```

**Rule of thumb:** if the test overrides a URL or secret constant that came from
`runtime_env`, patch the imported reference (`module.CONSTANT`). Patching
`os.environ` only works for `os.getenv` calls still evaluated at runtime — which
is the OLD pattern, not the post-hardening one.

## Anti-patterns (never do)

- **A hardcoded prod URL as an `os.getenv` fallback:**
  ```python
  # ❌ Silently leaks the prod URL in dev when the env var is missing
  FRONTEND_URL = os.getenv('FRONTEND_URL', 'https://app.example.com')
  ```
- **A hardcoded dev secret as a fallback:**
  ```python
  # ❌ The "secret" is in source; HMAC auth is now no protection at all
  INTERNAL_KEY = os.getenv('INTERNAL_KEY', 'dev-internal-key')
  ```
- **Two conflicting defaults across consumers** — one file defaulting to
  `localhost:5173` while another defaults to the prod URL. Centralize the
  module-level constant in `runtime_env.py` to make this impossible. (One
  hardening pass found a single URL with 2 conflicting defaults and another
  with 4.)
- **Pattern B without Pattern A** — a live binding might exist today, but it
  disappears on the next destructive deploy.
- **Pattern A without Pattern B** — the config is codified but the dangerous
  fallback still misroutes when the var goes missing.
- **Shipping Pattern B before live-binding** — the next deploy crashes the
  service at module import.
- **`monkeypatch.setenv` to override a module-level constant in a test** — it
  doesn't work; the constant locked at import. Use `monkeypatch.setattr`.

## Why this rule exists

A customer's production accounting-integration tokens were stored, for hours,
tagged as **sandbox** tokens. The cause: the `<PROVIDER>_ENVIRONMENT` env var was
never bound on the production service, and the code read it as
`os.getenv('<PROVIDER>_ENVIRONMENT', 'sandbox')`. Nothing errored. Nothing
logged. The integration simply pointed at the wrong world, and the customer
couldn't sync invoices until someone noticed by hand.

The failure mode is the point: a missing env var with a plausible default
produces **no signal at all**. It doesn't crash, it doesn't 500, it doesn't page.
It just quietly does the wrong thing in production. The fail-loud helper converts
that silence into a boot-time crash — which is loud, immediate, and catches the
problem in the deploy rather than in a customer's data.

A follow-on hardening pass across two services closed five HIGH-RISK vars and a
whole family of URL constants. Three separate test files broke during that work
from the same `@patch.dict(os.environ)` anti-pattern — hence the section above.
The pattern is real and it repeats.
