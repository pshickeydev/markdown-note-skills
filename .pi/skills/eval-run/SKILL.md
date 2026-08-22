---
name: eval-run
description: >-
  Run the agent-eval-harness evaluations for this repository's journal skills
  and report the results. Use when asked to run the evals, evaluate a skill,
  benchmark, score, or check for regressions on journal-note, journal-organize,
  or journal-weekly. Orchestrates eval/bin/run-eval.sh (pi is both the runner
  and the judge) and interprets the resulting summary.yaml against thresholds.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-run (Pi orchestrator)

You are orchestrating an evaluation run. The heavy lifting is done by
`eval/bin/run-eval.sh`, which sequences the harness pipeline
(workspace → execute → collect → score → report) with **pi** as both the skill
runner and the agent judge. Your job is to pick targets, run the driver, and
interpret the results — do not re-implement the pipeline.

Pinned to **agent-eval-harness v1.41.0**.

## Step 0 — Locate the repo and driver

```bash
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"
test -x eval/bin/run-eval.sh || echo "MISSING: eval/bin/run-eval.sh"
```

Run everything from `$ROOT`.

## Step 1 — Parse the request

Determine the **target config(s)** and options from what the user asked:

- A skill name → its config:
  - `journal-note` → `eval/journal-note/eval.yaml`
  - `journal-organize` → `eval/journal-organize/eval.yaml`
  - `journal-weekly` → `eval/journal-weekly/eval.yaml`
- "all" or unspecified → run all three.
- An explicit `--config <path>` → use it as-is.

Optional flags to pass through to the driver:

| User intent | Driver flag |
|-------------|-------------|
| Specific model | `--model <pattern>` (default: `models.skill` in the config) |
| Only some cases | `--cases <id...>` (e.g. `--cases 001-append-existing`) |
| Fast / free structural check only | `--no-llm-judges` (skips the pi agent judges) |
| Compare to a prior run | `--baseline <run-id>` |
| Custom id | `--run-id <id>` |

When the user just wants a quick check, prefer `--no-llm-judges` first (it runs
only the deterministic `check:` judges — no model tokens).

## Step 2 — Preflight

1. **Harness path.** The driver needs the harness checkout:
   ```bash
   echo "${AGENT_EVAL_HARNESS:-<unset>}"
   ```
   If unset, ask the user for the harness checkout path and either export it or
   pass `--harness <dir>`. Do not guess.
2. **Provider plugin + region.** Both the skill run and the judges go through pi
   using the `anthropic-vertex` **plugin** (`models.*` are `anthropic-vertex/…`).
   Do not use `pi auth check --provider anthropic-vertex` (returns
   `provider_not_found` for plugin providers). Instead:
   ```bash
   pi list | grep -i pi-anthropic-vertex          # plugin installed?
   echo "CLOUD_ML_REGION=${CLOUD_ML_REGION:-<unset>}"   # must not be "global"
   ```
   The wrappers load only that plugin and force region `us-east5` (override:
   `AGENT_EVAL_VERTEX_REGION`) when the ambient region is unset/`global` — the
   `global` location intermittently 404s for Claude models and breaks runs. If
   the plugin is missing or your models live in another region, fix that first
   (see `/skill:eval-setup`). Keep the `anthropic-vertex/` prefix on the models.
3. **This session's own model/region matter too.** These skills run inside your
   interactive pi session, which uses ITS default model + ambient
   `CLOUD_ML_REGION` — the wrappers only fix the eval *subprocess*. On this
   project the models are region-split and `global` intermittently 404s
   (`claude-opus-4-8` → global; `claude-opus-4-6`/`claude-sonnet-4-6` →
   us-east5). If the orchestrator session errors with a 404 “model ... not found
   in location global”, relaunch it pinned to a reliable pair, e.g.
   `CLOUD_ML_REGION=us-east5 pi --model anthropic-vertex/claude-opus-4-6`.

## Step 3 — Run

For each target config:

```bash
AGENT_EVAL_HARNESS="$AGENT_EVAL_HARNESS" \
  eval/bin/run-eval.sh --config eval/<name>/eval.yaml [--model <m>] [--cases <ids>] [--no-llm-judges]
```

This runs foreground and can take a while (each case is a real pi invocation;
agent judges add more). Report progress between configs. The driver prints the
`summary:` and `report:` paths on completion.

## Step 4 — Interpret

For each run, read the results and compare against the config's `thresholds:`:

```bash
cat eval/runs/<eval-name>/<run-id>/summary.yaml          # judges: mean / pass_rate; per_case
cat eval/runs/<eval-name>/<run-id>/run_result.json       # cost_usd, token_usage, num_turns, exit_code
```

**Reading tokens correctly** — `run_result.json` stores tokens as a nested
`token_usage` object, NOT flat `input_tokens`/`output_tokens` (querying those
returns nothing). Use the right keys:

```bash
python3 -c "import json,sys; d=json.load(open(sys.argv[1])); tu=d.get('token_usage') or {}; \
print(f\"cost \${d.get('cost_usd')}  in {tu.get('input')}  out {tu.get('output')}  turns {d.get('num_turns')}  exit {d.get('exit_code')}\")" \
  eval/runs/<eval-name>/<run-id>/run_result.json
```

Per-model and per-case breakdowns live in `d['per_model_usage']` and
`d['per_case'][<id>]['token_usage']`.

Then report, leading with a **Recommendation**:

- Per judge: `mean` / `pass_rate` and PASS/FAIL vs its threshold
  (`min_mean`, `min_pass_rate`). The deterministic judges (e.g. `note_appended`,
  `bullets_preserved`, `journals_untouched`) are the hard gates; the `*_quality`
  agent judge is the graded signal.
- Cost and tokens — `cost_usd` and `token_usage.input`/`token_usage.output`
  (populated by pi's `--mode json` via the wrapper). Do not report `?`: if a
  value looks missing, you queried the wrong key (see above), not a wrapper bug.
- The `report.html` path for the human-readable view.
- For any failing case, read its collected output under
  `eval/runs/<eval-name>/<run-id>/cases/<id>/artifacts/` and the judge rationale
  in `summary.yaml` to explain *why*.

## Step 5 — Next steps

Suggest, as appropriate:
- fix the SKILL.md and re-run (start with `--no-llm-judges` for a fast loop),
- run the other configs,
- `--baseline <prior-run-id>` to confirm a change didn't regress.

## Gotchas

- **Run from the repo root.** The driver resolves fixtures and the harness
  relative to the repo; it also `cd`s to the root itself, but your `pi auth` and
  `grep` steps assume `$ROOT`.
- **Agent judges spend pi tokens.** Use `--no-llm-judges` for a free, fast
  structural pass; run the full judges when you want the quality score.
- **Never touches the real vault.** The runner stages a throwaway fixture under
  the workspace `.work/`; a `WARNING` that the repo `AGENTS.md` points elsewhere
  is expected and harmless.
- **Confirmation-gated skills** (`journal-organize`, `journal-weekly`) run
  non-interactively — the runner injects a non-interactive system prompt.
- This skill is **not** part of the evaluated skill set (it lives in
  `.pi/skills/`, not `.agents/skills/`), so it never interferes with a run.
