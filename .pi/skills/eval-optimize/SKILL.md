---
name: eval-optimize
description: >-
  Automated improvement loop for a journal skill: run its eval, read the failing
  cases and judge rationale, edit the skill under test, re-run, and check for
  regressions against a baseline. Use when asked to optimize or improve a skill
  from its eval failures, or to iterate until thresholds pass.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-optimize (Pi orchestrator)

Closed loop: baseline → diagnose → edit → re-run → check regressions. Reuses
`eval/bin/run-eval.sh` and the harness regression check.

## Loop (default max 3 iterations; confirm scope with the user first)
```bash
cd "$(git rev-parse --show-toplevel)"
CFG=eval/<skill>/eval.yaml
```
1. **Baseline.** Full run, note the run-id:
   `eval/bin/run-eval.sh --config "$CFG"`  → baseline `<BASE>`.
2. **Diagnose.** Read `eval/runs/<eval-name>/<BASE>/summary.yaml` (failing judges
   + `rationale`) and the offending `cases/<id>/artifacts/…`. Identify the
   root cause in `.agents/skills/<skill>/SKILL.md`.
3. **Edit.** Make a targeted, minimal change to `.agents/skills/<skill>/SKILL.md`
   that addresses the diagnosed failure. Do not touch fixtures, judges, or
   thresholds (changing the test to pass is not optimization).
4. **Fast re-check.** `eval/bin/run-eval.sh --config "$CFG" --no-llm-judges`
   to confirm the deterministic gates pass cheaply.
5. **Verify + regression.** Full re-run against the baseline:
   `eval/bin/run-eval.sh --config "$CFG" --baseline <BASE>` — this runs the
   regression check (thresholds vs baseline) and the report shows deltas.
   (Pairwise is a no-op here: these configs define no `pairwise` judge, so the
   driver tolerates and skips it — rely on the regression + per-judge means.)
6. Repeat from step 2 until all thresholds pass with no regressions, or the
   iteration budget is exhausted. Summarize what changed and the score delta.

## Rules
- Only edit the skill under test; never weaken judges/thresholds/fixtures.
- Prefer the smallest change that fixes the diagnosed cause.
- Stop and report if a change regresses a previously-passing case.
