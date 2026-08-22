---
name: eval-review
description: >-
  Review a completed eval run interactively: read judge scores and per-case
  artifacts, discuss quality with the user, capture feedback, and propose
  SKILL.md fixes. Use when asked to review eval results, inspect failures, or
  triage a run.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-review (Pi orchestrator)

Human-in-the-loop review of a run. This is an agent workflow — no script.

## Steps
```bash
cd "$(git rev-parse --show-toplevel)"
ls eval/runs/<eval-name>/                       # pick a run-id
```
1. Read the summary and metrics:
   - `eval/runs/<eval-name>/<id>/summary.yaml` — per-judge `mean`/`pass_rate` and
     `per_case` `{value, rationale}`.
   - `eval/runs/<eval-name>/<id>/run_result.json` — cost, tokens, exit codes.
2. For each case worth inspecting (start with failures / low scores), read its
   collected output and compare to expectations:
   - `eval/runs/<eval-name>/<id>/cases/<case>/artifacts/…` (the generated files),
   - the judge `rationale` in `summary.yaml`,
   - the case's `annotations.yaml` and `reference/` in the dataset.
3. Present a concise per-case verdict and ask the user for their assessment.
4. Capture the discussion into `eval/runs/<eval-name>/<id>/review.yaml`
   (per-case human notes / scores) — this is the file `/skill:eval-mlflow`
   (`attach_feedback --action push`) and the report consume. For the exact keys,
   read the harness's own schema first:
   `$AGENT_EVAL_HARNESS/skills/eval-review/SKILL.md` (and its `prompts/`), so the
   file parses cleanly downstream.
5. Propose concrete, minimal `.agents/skills/<skill>/SKILL.md` edits for the
   failures. Hand off to `/skill:eval-optimize` to apply-and-verify, or make the
   edits and re-run with `/skill:eval-run`.

Do not modify the run artifacts other than writing `review.yaml`.
