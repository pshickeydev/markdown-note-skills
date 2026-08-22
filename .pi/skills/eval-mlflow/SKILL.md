---
name: eval-mlflow
description: >-
  Log eval run results to MLflow, sync the dataset, and push/pull judge and
  human feedback. Use when asked to log a run to MLflow, sync the eval dataset,
  or push/pull feedback annotations. Requires the harness [mlflow] extra and an
  mlflow.experiment configured in the eval.yaml.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-mlflow (Pi orchestrator)

Optional MLflow integration. **Prerequisites** (confirm before running):

- harness installed with the extra: `pip install -e '<harness>[mlflow]'`,
- an `mlflow:` block in the target config (`experiment:`, optionally
  `tracking_uri:`), or `MLFLOW_TRACKING_URI` in the environment.

Our configs leave `mlflow.experiment` unset by default, so add it (via
`/skill:eval-analyze`) before using this, or the log step has nowhere to write.

## Actions
```bash
cd "$(git rev-parse --show-toplevel)"
CFG=eval/journal-note/eval.yaml
ID=<run-id>     # a run-id under eval/runs/<eval-name>/

# Push cases to an MLflow dataset
eval/bin/harness.sh skills/eval-mlflow/scripts/sync_dataset.py --config "$CFG"

# Log a run's params/metrics/artifacts + build the trace
eval/bin/harness.sh skills/eval-mlflow/scripts/log_results.py --run-id "$ID" --config "$CFG"

# Push judge (summary.yaml) + human (review.yaml) feedback to traces, or pull UI annotations
eval/bin/harness.sh skills/eval-mlflow/scripts/attach_feedback.py --run-id "$ID" --config "$CFG" --action push
eval/bin/harness.sh skills/eval-mlflow/scripts/attach_feedback.py --run-id "$ID" --config "$CFG" --action pull
```
Run any script with `--help` to confirm optional flags. Report the MLflow
experiment/run URLs the scripts print.
