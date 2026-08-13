#!/usr/bin/env python3
"""Deterministic half of /lessons-audit.

Reads ~/.claude/lessons.jsonl and answers five questions that don't need a
model, so the model only spends judgment on the ones that do:

  1. Which failure classes cleared a promotion threshold? (2x -> rule, 3x -> enforcement)
  2. Which classes RECURRED after their rule was written? (rule isn't working)
  3. Which rules/memories have never appeared in the ledger? (context tax)
  4. What does the trend look like month over month?
  5. Is the rules/ corpus itself over budget — any single file too big, any
     glob too broad, or the total larger than last time? (a corpus that
     grows unchecked for months before its first consolidation pass is the
     failure this question exists to catch early.)

Output is JSON on stdout. Pass --window-days N to bound questions 1/2/4
(default: all history). Question 3 always considers all history — a rule
that hasn't fired in 6 months is exactly the finding. Question 5 always
considers current corpus state (there's no "window" for a snapshot).
"""

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from pathlib import Path

HOME = Path.home()
LEDGER = Path(os.environ.get("LESSONS_LEDGER", HOME / ".claude" / "lessons.jsonl"))
RULES_DIR = Path(os.environ.get("LESSONS_RULES_DIR", HOME / ".claude" / "rules"))
MEMORY_DIR = Path(
    os.environ.get(
        "LESSONS_MEMORY_DIR",
        HOME / ".claude" / "projects" / "memory",
    )
)

RULE_THRESHOLD = 2       # class seen this many times with no rule -> write one
ENFORCE_THRESHOLD = 3    # class seen this many times still unenforced -> make it executable

CORPUS_HISTORY = Path(
    os.environ.get("LESSONS_CORPUS_HISTORY", HOME / ".claude" / "skills" / "lessons-audit" / "corpus-history.jsonl")
)
SIZE_BUDGET = 150        # lines; above this a rule is a split-to-history candidate
CORPUS_BUDGET = 5000     # total rules/*.md lines; above this, flag "run a consolidation pass"
# A rule whose `paths:` frontmatter is a superset of this glob set fires on
# nearly any code touch in nearly any repo, i.e. "path-conditional" in name
# only. A rule can suppress this flag deliberately (it's cross-cutting by
# design, e.g. a pre-push adversarial gate) by including the literal string
# `broad-glob-ok` anywhere in its first 20 lines. Tune this set to whatever
# your own corpus's copy-pasted broad glob template looks like.
BROAD_GLOB_SET = {
    "**/*.tsx", "**/*.ts", "**/*.jsx", "**/*.py",
    "**/backend/**", "**/migrations/**", "**/*.sql",
}


def load_ledger():
    if not LEDGER.exists():
        return [], []
    rows, bad = [], []
    for i, raw in enumerate(LEDGER.read_text().splitlines(), 1):
        raw = raw.strip()
        if not raw:
            continue
        try:
            rec = json.loads(raw)
            # A half-written line from a clobbered append would land here.
            datetime.strptime(rec["date"], "%Y-%m-%d")
            rec["class"]
            rows.append(rec)
        except Exception as exc:
            bad.append({"line": i, "error": str(exc), "raw": raw[:200]})
    return rows, bad


def git_first_seen(path: Path):
    """When did this rule actually land? mtime lies after any edit or a fresh
    clone, so ask git; fall back to mtime only when git has no history."""
    try:
        out = subprocess.run(
            ["git", "log", "--diff-filter=A", "--follow", "--format=%ad",
             "--date=short", "--", path.name],
            cwd=path.parent, capture_output=True, text=True, timeout=10,
        )
        lines = [l for l in out.stdout.splitlines() if l.strip()]
        if lines:
            return lines[-1]
    except Exception:
        pass
    return date.fromtimestamp(path.stat().st_mtime).isoformat()


def resolve_rule(name: str):
    """A `rule` field may name a rules/*.md or a memory *.md. Return its path."""
    if not name:
        return None
    stem = re.sub(r"\.md$", "", name)
    for cand in (RULES_DIR / f"{stem}.md", MEMORY_DIR / f"{stem}.md"):
        if cand.exists():
            return cand
    return None


def parse_frontmatter_paths(text: str):
    """Pull the `paths:` glob list out of a rule's YAML frontmatter without a
    full YAML parser — frontmatter here is always a flat `paths:` block of
    `  - "glob"` lines between the leading `---` markers."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return []
    try:
        end = lines[1:].index("---") + 1
    except ValueError:
        return []
    globs = []
    for line in lines[1:end]:
        m = re.match(r'^\s*-\s*["\']?(.+?)["\']?\s*$', line)
        if m and ":" not in line.split(m.group(1))[0]:
            globs.append(m.group(1))
    return globs


def corpus_health():
    """Q5: is the rules/ corpus itself over budget?"""
    files = sorted(RULES_DIR.glob("*.md"))
    per_file = []
    for f in files:
        text = f.read_text()
        n = len(text.splitlines())
        per_file.append((f, text, n))
    total_lines = sum(n for _, _, n in per_file)

    oversized = sorted(
        [{"rule": f.stem, "lines": n} for f, _, n in per_file if n > SIZE_BUDGET],
        key=lambda e: -e["lines"],
    )

    broad_glob = []
    for f, text, n in per_file:
        globs = set(parse_frontmatter_paths(text))
        if BROAD_GLOB_SET <= globs and "broad-glob-ok" not in text[:800]:
            broad_glob.append({"rule": f.stem, "lines": n})

    trend = []
    if CORPUS_HISTORY.exists():
        for raw in CORPUS_HISTORY.read_text().splitlines():
            raw = raw.strip()
            if raw:
                try:
                    trend.append(json.loads(raw))
                except Exception:
                    pass

    entry = {"date": date.today().isoformat(), "total_lines": total_lines, "file_count": len(files)}
    CORPUS_HISTORY.parent.mkdir(parents=True, exist_ok=True)
    with CORPUS_HISTORY.open("a") as fh:
        fh.write(json.dumps(entry) + "\n")

    delta_since_last = None
    if trend:
        delta_since_last = total_lines - trend[-1]["total_lines"]

    return {
        "total_lines": total_lines,
        "file_count": len(files),
        "budget": CORPUS_BUDGET,
        "over_budget": total_lines > CORPUS_BUDGET,
        "oversized_rules": oversized,
        "size_budget_per_rule": SIZE_BUDGET,
        "broad_glob_candidates": broad_glob,
        "delta_since_last_run": delta_since_last,
        "history": trend[-6:],
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--window-days", type=int, default=None)
    args = ap.parse_args()

    rows, malformed = load_ledger()
    cutoff = None
    if args.window_days:
        cutoff = (date.today() - timedelta(days=args.window_days)).isoformat()
    windowed = [r for r in rows if not cutoff or r["date"] >= cutoff]

    by_class = defaultdict(list)
    for r in windowed:
        by_class[r["class"]].append(r)

    # --- Q1: promotion thresholds -----------------------------------------
    needs_enforcement, needs_rule = [], []
    for cls, hits in sorted(by_class.items(), key=lambda kv: -len(kv[1])):
        n = len(hits)
        enforced = {h.get("enforced", "none") for h in hits}
        rules = {h["rule"] for h in hits if h.get("rule")}
        entry = {
            "class": cls,
            "count": n,
            "repos": sorted({h["repo"] for h in hits}),
            "files": sorted({h["file"] for h in hits})[:8],
            "rule": sorted(rules) or None,
            "first_seen": min(h["date"] for h in hits),
            "last_seen": max(h["date"] for h in hits),
        }
        if n >= ENFORCE_THRESHOLD and enforced == {"none"}:
            needs_enforcement.append(entry)
        elif n >= RULE_THRESHOLD and not rules:
            needs_rule.append(entry)

    # --- Q2: recurrence after the rule was written ------------------------
    # This is the finding that matters most: a documented class that keeps
    # happening is evidence the prose isn't working, not that it needs restating.
    recurred_after_rule = []
    for cls, hits in by_class.items():
        for rule_name in sorted({h["rule"] for h in hits if h.get("rule")}):
            path = resolve_rule(rule_name)
            if not path:
                recurred_after_rule.append({
                    "class": cls, "rule": rule_name, "error": "rule file not found",
                    "hits_after": [], "count_after": 0,
                })
                continue
            written = git_first_seen(path)
            after = sorted(h["date"] for h in hits if h["date"] > written)
            if after:
                recurred_after_rule.append({
                    "class": cls,
                    "rule": rule_name,
                    "rule_written": written,
                    "count_after": len(after),
                    "hits_after": after,
                    "still_unenforced": all(
                        h.get("enforced", "none") == "none" for h in hits
                    ),
                })
    recurred_after_rule.sort(key=lambda e: -e["count_after"])

    # --- Q3: rules that have never fired ----------------------------------
    cited = {re.sub(r"\.md$", "", r["rule"]) for r in rows if r.get("rule")}
    never_cited = []
    for path in sorted(RULES_DIR.glob("*.md")):
        if path.stem not in cited:
            never_cited.append({
                "rule": path.stem,
                "path": str(path),
                "bytes": path.stat().st_size,
                "first_seen": git_first_seen(path),
            })
    never_cited.sort(key=lambda e: -e["bytes"])

    # --- Q4: trend ---------------------------------------------------------
    per_month = Counter(r["date"][:7] for r in rows)

    # --- Q5: corpus health (rules/ itself, not the ledger) ------------------
    health = corpus_health()

    json.dump({
        "ledger": str(LEDGER),
        "window_days": args.window_days,
        "total_entries": len(rows),
        "entries_in_window": len(windowed),
        "distinct_classes": len(by_class),
        "malformed_lines": malformed,
        "needs_enforcement": needs_enforcement,
        "needs_rule": needs_rule,
        "recurred_after_rule": recurred_after_rule,
        "rules_never_cited": never_cited,
        "entries_per_month": dict(sorted(per_month.items())),
        "thresholds": {"rule": RULE_THRESHOLD, "enforce": ENFORCE_THRESHOLD},
        "corpus_health": health,
    }, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
