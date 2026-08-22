---
name: eval-anova
description: >-
  Design and run a multi-condition (matrix) eval experiment, then compute ANOVA
  + a cost/quality Pareto frontier and render a comparison. Use when asked to
  run a DoE/matrix experiment, compare configurations statistically, or run
  ANOVA over eval runs. Advanced — requires the harness [anova] extra and a
  matrix: block in the eval.yaml.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-anova (Pi orchestrator)

Design-of-Experiments over a `matrix:` of agent configurations. Each matrix cell
drives the standard eval-run pipeline once (so with our `runner: cli`, each cell
runs through pi), then the runs are analyzed together.

**Prerequisites** (confirm first):
- harness with the extra: `pip install -e '<harness>[anova]'`,
- a `matrix:` block added to the target `eval.yaml` (conditions × replications).
  See the harness `skills/eval-anova/QUICKSTART.md` and `eval/anova-example/`.

## Steps
```bash
cd "$(git rev-parse --show-toplevel)"
CFG=eval/journal-note/eval.yaml

# 1) Design + cost estimate (no execution)
eval/bin/harness.sh skills/eval-anova/scripts/design.py --config "$CFG"        # run --help for flags

# 2) Fan out the matrix over eval-run (condition × replication)
eval/bin/harness.sh skills/eval-anova/scripts/orchestrate.py --config "$CFG"

# 3) Analyze (ANOVA + Pareto) and render the comparison
eval/bin/harness.sh skills/eval-anova/scripts/analyze.py  --config "$CFG"       # run --help
eval/bin/harness.sh skills/eval-anova/scripts/report.py   --config "$CFG"       # run --help
```
Always run each script with `--help` first to confirm its exact arguments —
this stage's CLIs are the least stable. Report the `anova.json` and the rendered
comparison HTML paths. This is optional/advanced; routine evaluation only needs
`/skill:eval-run`.
