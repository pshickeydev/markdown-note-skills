---
name: eval-analyze
description: >-
  Create, update, or validate an eval.yaml for a journal skill. Use when asked
  to analyze a skill for evaluation, (re)generate or fix an eval config, or
  validate eval.yaml. Config authoring follows this repo's conventions; wraps
  the harness validate_eval.py and assess_skills.py.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-analyze (Pi orchestrator)

Author or validate an `eval/<skill>/eval.yaml`. The three journal configs are
already authored, so the common uses are **validate** and **update**.

## Validate an existing config
```bash
cd "$(git rev-parse --show-toplevel)"
eval/bin/harness.sh skills/eval-analyze/scripts/validate_eval.py config eval/journal-note/eval.yaml
```
Fix any reported schema errors and re-validate.

## Assess which skills would benefit from evals
```bash
eval/bin/harness.sh skills/eval-analyze/scripts/assess_skills.py    # run --help for flags
```

## Create or update a config (agent work)
Read the target `.agents/skills/<skill>/SKILL.md`, then write
`eval/<skill>/eval.yaml` following the **conventions in `eval/README.md`** — do
not copy the harness's generic template blindly. Match the existing configs:
- `runner: {type: cli, command: "{config_dir}/../bin/run-skill.sh <skill> {workspace} {output_dir} {model} {system_prompt}"}`
- `execution: {mode: case, skill: <skill>, arguments: "{args}", env: {PROJECT_ROOT: $PWD}}`
- `models: {skill: anthropic-vertex/claude-sonnet-4-6, judge: anthropic-vertex/claude-opus-4-6}` — pi model ids **with the provider prefix** (a bare `claude-*` id resolves to the direct `anthropic` provider and fails asking for Anthropic auth; `anthropic-vertex/` pins them to Vertex)
- `outputs: [{path: artifacts, schema: …}]`  ← never `output` (reserved by agent judges)
- deterministic `check:` judges for the hard invariants,
- one `*_quality` **agent judge** (`agent.runner.type: cli` → `run-judge.sh`, `inputs: [artifacts]`, reference-free rubric using `{{ outputs }}`),
- `thresholds:` per judge.
Then validate (above) and smoke-test with `/skill:eval-run <skill> --no-llm-judges`.

Also update `dataset/` (cases) via `/skill:eval-dataset` if the schema changed.
