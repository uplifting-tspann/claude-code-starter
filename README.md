# claude-code-starter

An opinionated starter for working with [Claude Code](https://claude.ai/code).
Six-plus months of accumulated rules, hooks, conventions, and workflow patterns
— extracted from a real working setup, packaged so you don't have to invent
them from scratch on a new machine or a new product.

**Status:** v0.1.1 — directory skeleton + portable rules + hooks +
functional `bootstrap.sh` and `scripts/install-claude-config.sh`. Project
templates and the full skill set are coming in follow-up passes. See
[What's in v0.1 vs. coming](#whats-in-v01-vs-coming) below.

## Who this is for

- **You're starting a new product** and want the same workflow infrastructure
  you've already built somewhere else — not a clean slate.
- **A friend asked how you work with Claude Code** and you want to point them
  at something more than dotfiles — an explained, opinionated way of working.
- **You got a new machine** and want one script to set up the whole toolchain
  plus your `~/.claude/` config.

## What this *isn't*

- Not framework-agnostic. This starter is shaped by GCP + Postgres + monorepo
  habits. Adapt the conventions, but the choice of opinions is the point.
- Not auto-everything. Hooks and rules nudge you (and Claude) toward good
  habits, but nothing here silently overwrites your work.
- Not Anthropic-official. This is one person's working setup, made portable.

## Quickstart

```bash
# 1. Clone (or create a new project from this template)
gh repo create my-new-project --template uplifting-tspann/claude-code-starter --public --clone
cd my-new-project

# 2. Set up the machine (Homebrew, Brewfile packages, gcloud, Firebase CLI, etc.)
#    and install the ~/.claude config skeleton in one step.
./bootstrap.sh

# Or, if you've already done the machine setup and just want the ~/.claude
# config skeleton:
./scripts/install-claude-config.sh
```

Both scripts are idempotent and conservative:

- `bootstrap.sh` skips Homebrew if already installed, runs `brew bundle` to
  install/update from the included `Brewfile`, checks for the Claude Code
  CLI (without auto-installing it), and invokes the config installer.
- `scripts/install-claude-config.sh` **never overwrites** existing files in
  `~/.claude/` by default. Conflicts are reported and skipped. Use
  `--force` to overwrite (existing files get a `.bak.YYYYMMDDHHMMSS` backup
  first). `settings.json` gets extra-special handling: if it already
  exists, the rendered template is written next to it as
  `settings.json.suggested` for hand-diffing rather than touched.

Use `--dry-run` on either script to preview what it would do without making
any changes. `--help` on either prints full usage.

After running bootstrap, follow the printed prompts to auth `gh`, `gcloud`,
and `claude` interactively.

## Repository layout

```
claude-code-starter/
├── README.md                       This file — quickstart + what ships in v0.1
├── WHY.md                          Pedagogical deep dive: why each rule/pattern exists
├── LICENSE                         MIT
├── bootstrap.sh                    One-shot macOS machine setup
├── Brewfile                        Homebrew formulae + cask for bootstrap
├── .vscode/                        Recommended VS Code extensions + project-level editor settings
├── claude/                         Skeleton for your ~/.claude/ install
│   ├── rules/                      10 portable rules (see claude/rules/README)
│   ├── skills/                     1 portable skill so far (more coming)
│   ├── hooks/                      Stop hook + pre-commit checker
│   ├── memory/                     Memory model templates (README + MEMORY.md.example + per-type examples)
│   ├── CLAUDE.md.template          Global instructions skeleton (thin — identity + universal prefs)
│   └── settings.json.template      Hooks wiring + permissions (with YOUR-USER placeholder)
├── project-template/               Scaffolding for each new project
│   ├── CLAUDE.md.template          Project-level conventions skeleton (sections for stack, infra, conventions, etc.)
│   └── workstream-template/        state.md / decisions.md / open_questions.md
└── scripts/
    ├── install-claude-config.sh    Installs claude/ skeleton into ~/.claude/
    └── sync-from-source.sh         Diffs your live ~/.claude against the template; report/diff/interactive modes
```

## What's in v0.1 vs. coming

**Shipped:**
- [`WHY.md`](WHY.md) — pedagogical deep dive: why each rule/pattern
  exists, when to use rules vs. skills vs. hooks, how to evolve the
  system. Read this if you're trying to understand the workflow rather
  than just copy it.
- 10 portable rules in `claude/rules/`, scrubbed of project-specific
  references (proof-of-work, what's-next, commit-discipline, no-glazing,
  dates-and-times, WCAG-AA contrast, verify-db-objects, e2e-test-evolution,
  help-article-evolution, changelog-evolution)
- 2 hooks in `claude/hooks/` (Stop hook enforcing Proof of Work; pre-commit
  secret/console.log scanner)
- 4 skills in `claude/skills/`: `consolidate-memory` (no config),
  plus `proof`, `cross-repo-search`, and `test-runner` — the latter
  three read `~/.claude/projects-config.json` for project paths,
  dev commands, and test commands
- `claude/projects-config.json.example` — example schema for the
  shared per-project config (copy to `~/.claude/projects-config.json`
  and edit before invoking `cross-repo-search` / `test-runner`)
- `claude/settings.json.template` with hooks wired up + a `YOUR-USER`
  placeholder that `scripts/install-claude-config.sh` substitutes
- `claude/CLAUDE.md.template` — thin global Claude Code instructions
  (identity + universal prefs); installer writes it (or
  `CLAUDE.md.suggested` alongside existing) without auto-overwriting
- `project-template/CLAUDE.md.template` — per-project conventions
  skeleton with sections for stack, infra, DB, frontend/backend
  conventions, testing, deploy — fill in the bracketed placeholders
  when scaffolding a new project from this template
- `claude/memory/` — memory model templates: README explaining the
  model + `MEMORY.md.example` index + four per-type memory examples
  (user, feedback, project, reference). These are *examples*, not
  files the installer copies into your live memory dir — memory is
  yours to write
- `bootstrap.sh` — macOS machine setup (Homebrew + Brewfile + Claude Code
  check + config installer). The Brewfile installs the CLI toolchain
  (`git`, `gh`, `node`, `jq`, `cloud-sql-proxy`, `firebase-cli`,
  `gcloud-cli`, WeasyPrint deps) plus two GUI apps as casks
  (`visual-studio-code`, `google-chrome`) for the new-machine case.
  Comment out the casks if you manage GUI apps another way
- `scripts/install-claude-config.sh` — copies `claude/` skeleton into
  `~/.claude/` with skip-existing default + `--force` for overwrites
- `.vscode/extensions.json` + `.vscode/settings.json` — recommended
  extension set (ESLint, Prettier, Tailwind IntelliSense, Playwright,
  Python/Pylance, GitLens, GitHub PRs, YAML/TOML, spell-check) plus
  project-level editor settings (format-on-save, per-language
  formatters, search/watcher excludes, ESLint auto-fix). When you open
  the project, VS Code prompts to install recommended extensions
- `scripts/sync-from-source.sh` — diffs your live `~/.claude/{rules,
  skills,hooks}` against the template repo's `claude/` dir. Default
  is a read-only report; `--diff` includes unified diffs; `--interactive`
  prompts per-file (promote LIVE→template, update template→LIVE, skip).
  Run periodically to keep the template and your live install in sync
  as both evolve
- `Brewfile` capturing the toolchain
- `project-template/workstream-template/` — state.md / decisions.md /
  open_questions.md pattern
- LICENSE, .gitignore, this README

**Coming in follow-up passes:**
- `project-template/.gcloudignore.template` (and other useful per-project
  defaults)
- More portable skills (db-migrate, db-verify, schema-diff, log-tail,
  code-cleanup, repo-assessment — currently project-pathed in the
  source, need generalization. Will likely extend
  `projects-config.json` with `database` and `services` blocks.)

## Why opinionated?

A neutral, framework-agnostic starter ends up being just a directory tree
with no point of view. The value here is the *opinions*: what conventions
actually pay off in practice, why each rule exists, what failure mode it
prevents. Fork it and bend it to your stack — but the opinions are the
deliverable.

For the long version — when to use rules vs. skills vs. hooks, why the
mandatory end-of-turn sections matter, the workstream model, how to
evolve the system as you go — read [WHY.md](WHY.md).

## License

MIT. See [LICENSE](LICENSE).
