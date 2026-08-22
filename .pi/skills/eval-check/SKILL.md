---
name: eval-check
description: >-
  Scan this repository's skills and eval configs as a system for broken
  cross-references, missing scripts, orphan skills, and overlap. Use when asked
  to check harness/config health, find broken references, or audit the eval
  setup. Wraps the harness reference_checker.py and harness_inventory.py.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-check (Pi orchestrator)

Static health scan of the repo's skills/configs. Read-only.

## Steps
```bash
cd "$(git rev-parse --show-toplevel)"

# Cross-reference health: broken refs, missing scripts, orphan skills
eval/bin/harness.sh skills/eval-check/scripts/reference_checker.py --root . --format text

# Inventory of configuration artifacts
eval/bin/harness.sh skills/eval-check/scripts/harness_inventory.py --root . --format text
```
Add `--format yaml` for machine-readable output if you want to post-process.

## Interpret
Summarize findings grouped by severity. **Caveat:** these checkers are oriented
at Claude Code projects (they also look for `commands/`, `CLAUDE.md`, hooks).
This repo has none of those, so "missing command/CLAUDE.md" style findings are
expected and not actionable — focus on genuinely broken references within
`.agents/skills/**` and `eval/**/eval.yaml`.
