---
name: eval-compare
description: >-
  Build a self-contained HTML comparison report across multiple eval runs or
  models for the same skill. Use when asked to compare runs, compare models,
  benchmark two configs, or produce a comparison report. Wraps the harness
  compare.py.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-compare (Pi orchestrator)

Compare several completed runs of the **same** eval (e.g. different models, or
before/after a skill change). compare.py scans a directory whose children are
run directories (each with `summary.yaml`, `run_result.json`, `report.html`).

## Steps
```bash
cd "$(git rev-parse --show-toplevel)"

# 1) Discover the runs the tool will include (sanity check the input dir)
eval/bin/harness.sh skills/eval-compare/scripts/compare.py discover eval/runs/journal-note

# 2) Generate the comparison report
eval/bin/harness.sh skills/eval-compare/scripts/compare.py generate eval/runs/journal-note \
  --output eval/runs/_compare/journal-note \
  --title "journal-note: model comparison"
```
`eval/runs/<eval-name>/` already accumulates one subdir per run-id, so it is the
natural input dir. To compare a curated subset, first copy those run dirs into a
fresh folder and point `generate` at it. Run `compare.py --help` /
`compare.py generate --help` if you need other flags (e.g. `--overview`).

## Report
Tell the user the output HTML path (`.../index.html` under `--output`). If an
`/eval-anova` `anova.json` is present in the input dir, the report gains a
statistical-significance section automatically.
