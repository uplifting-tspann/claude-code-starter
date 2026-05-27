#!/bin/bash
# Hook script: Pre-commit validation checks
# Reference this from settings.json PreToolUse hooks

INPUT=$(cat)

# Check for secrets or credentials in file content
if echo "$INPUT" | grep -qiE "(password|secret|api_key|token)\s*=\s*['\"][^'\"]+['\"]"; then
  echo "WARNING: Possible hardcoded secret detected. Review before committing."
  exit 1
fi

# Check for console.log in TypeScript/JavaScript files
if echo "$INPUT" | grep -qE "console\.(log|debug)\("; then
  echo "WARNING: console.log/debug statement detected. Remove before committing."
  # Non-blocking warning (exit 0)
  exit 0
fi

exit 0
