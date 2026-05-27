# claude-code-starter

An opinionated starter for working with [Claude Code](https://claude.ai/code).
Six-plus months of accumulated rules, hooks, conventions, and workflow patterns
— extracted from a real working setup, packaged so you don't have to invent
them from scratch on a new machine or a new product.

**Status:** v0.1 — directory skeleton + portable rules + hooks. Bootstrap
script, project templates, and the full skill set are coming in follow-up
passes. See [What's in v0.1 vs. coming](#whats-in-v01-vs-coming) below.

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

Once v0.1.x ships the bootstrap script, the install will be:

```bash
# 1. Create a new project from this template
gh repo create my-new-project --template uplifting-tspann/claude-code-starter --public --clone
cd my-new-project

# 2. Set up the machine (Homebrew, gcloud, Node, etc.)
./bootstrap.sh

# 3. Copy the .claude/ skeleton into your home dir
./scripts/install-claude-config.sh
```

For now (v0.1), the rules and hooks can be copied manually:

```bash
cp -r claude/rules/*.md       ~/.claude/rules/
cp -r claude/skills/*         ~/.claude/skills/
cp    claude/hooks/*.sh       ~/.claude/hooks/
chmod +x                      ~/.claude/hooks/*.sh
```

Then wire the Stop hook in `~/.claude/settings.json` (example shape ships in
`claude/settings.json.template` in a later pass).

## Repository layout

```
claude-code-starter/
├── README.md                       This file — quickstart + what ships in v0.1
├── WHY.md                          [coming] Pedagogical: why each rule exists
├── LICENSE                         MIT
├── bootstrap.sh                    [coming] One-shot machine setup
├── Brewfile                        Homebrew formulae + cask for bootstrap
├── .vscode/                        [coming] Recommended editor settings
├── claude/                         Skeleton for your ~/.claude/ install
│   ├── rules/                      10 portable rules (see claude/rules/README)
│   ├── skills/                     1 portable skill so far (more coming)
│   ├── hooks/                      Stop hook + pre-commit checker
│   ├── memory/                     [coming] Memory model template
│   ├── CLAUDE.md.template          [coming] Global instructions skeleton
│   └── settings.json.template      [coming] Hooks wiring + permissions
├── project-template/               [coming] Per-project scaffolding
│   ├── CLAUDE.md.template          Project-level conventions skeleton
│   └── workstream-template/        state.md / decisions.md / open_questions.md
└── scripts/                        [coming] sync-from-source, install-claude-config
```

## What's in v0.1 vs. coming

**v0.1 (this commit):**
- 10 portable rules in `claude/rules/` (proof-of-work, what's-next,
  commit-discipline, no-glazing, dates-and-times, WCAG-AA, etc.)
- 2 hooks in `claude/hooks/` (Stop hook enforcing Proof of Work; pre-commit
  secret/console.log scanner)
- 1 skill in `claude/skills/` (consolidate-memory)
- Brewfile capturing the toolchain
- LICENSE, .gitignore, this README

**Coming in follow-up passes:**
- `bootstrap.sh` — one-shot Homebrew + gcloud + gh + Claude Code install
- `claude/CLAUDE.md.template` — global instructions skeleton with placeholders
- `claude/settings.json.template` — Stop hook wiring + permissions baseline
- `claude/memory/` — MEMORY.md index pattern + per-topic file template
- `project-template/` — per-project CLAUDE.md, workstream template, `.gcloudignore`
- More portable skills (test-runner, db-migrate, db-verify, schema-diff, log-tail,
  code-cleanup, cross-repo-search — currently Uplift-pathed, need generalization)
- `WHY.md` — the deep dive: why each rule, when to use what, how to evolve
- `scripts/sync-from-source.sh` — keep the template in sync with your live
  `~/.claude/` as you iterate
- Light Uplift-reference scrub on the rules (the patterns are general, but
  some examples mention specific repos/incidents that should be abstracted)

## Why opinionated?

A neutral, framework-agnostic starter ends up being just a directory tree
with no point of view. The value here is the *opinions*: what conventions
actually pay off in practice, why each rule exists, what failure mode it
prevents. Fork it and bend it to your stack — but the opinions are the
deliverable.

## License

MIT. See [LICENSE](LICENSE).
