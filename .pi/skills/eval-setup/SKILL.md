---
name: eval-setup
description: >-
  Verify the environment before running evaluations: python3/git/pi on PATH, the
  agent-eval-harness install (AGENT_EVAL_HARNESS + importable agent_eval), pi
  auth for the models the configs use, and the expected directories. Use when
  setting up evals, before a first run, or when a run fails on prerequisites.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-setup (Pi orchestrator)

Preflight check for the eval harness. Report a clear PASS/FIX list; do not
guess or auto-install without asking.

## Step 0 — Repo root
```bash
cd "$(git rev-parse --show-toplevel)"
```

## Step 1 — Tooling + harness install
```bash
command -v python3 git pi || echo "MISSING a required tool"
python3 -c "import agent_eval, yaml; print('agent_eval + pyyaml OK')"
echo "AGENT_EVAL_HARNESS=${AGENT_EVAL_HARNESS:-<unset>}"
```
- `agent_eval` import fails → the harness isn't installed: `pip install -e <harness>` (at tag `v1.41.0`).
- `AGENT_EVAL_HARNESS` unset → ask the user for the checkout path; the `eval/bin/*` drivers need it.

## Step 2 — Harness env check
```bash
eval/bin/harness.sh skills/eval-setup/scripts/check_env.py --config eval/journal-note/eval.yaml
```
This checks dependencies, dirs, and (for its own built-in judges) API keys /
MLflow. **For our setup, `ANTHROPIC_API_KEY` and MLflow warnings are safe to
ignore** — skills and judges run through pi, and `mlflow.experiment` is unset.

## Step 3 — anthropic-vertex provider (plugin + region)
The configs target the **`anthropic-vertex`** provider, which is a pi **plugin**
(the `models.*` ids are `anthropic-vertex/…`). Do NOT use
`pi auth check --provider anthropic-vertex` — it returns `provider_not_found`
(the check doesn't know plugin providers) even when runs work.

1. **Plugin installed:**
   ```bash
   pi list | grep -i pi-anthropic-vertex   # e.g. npm:@twogiants/pi-anthropic-vertex
   ```
   Missing → install it (`pi install npm:@twogiants/pi-anthropic-vertex`) or set
   `AGENT_EVAL_PI_EXTENSION` to its path.
2. **Region is not `global`:**
   ```bash
   echo "CLOUD_ML_REGION=${CLOUD_ML_REGION:-<unset>}"
   ```
   The plugin uses `CLOUD_ML_REGION`; `global` intermittently 404s for Claude
   models and breaks multi-step runs. The wrappers already override unset/`global`
   to `us-east5` (or `AGENT_EVAL_VERTEX_REGION`) — confirm your models exist in
   that region (Vertex Model Garden), and set `AGENT_EVAL_VERTEX_REGION` if not.
3. **Smoke the provider** (real 1-token call via the plugin only):
   ```bash
   CLOUD_ML_REGION="${AGENT_EVAL_VERTEX_REGION:-us-east5}" pi --print --no-session \
     --no-extensions -e "$(pi list | awk '/pi-anthropic-vertex/{getline;print;exit}' | xargs)" \
     --model anthropic-vertex/claude-sonnet-4-6 'Reply one word: ok'
   ```
   `ok` → provider + Vertex auth + region are good. A 404 “model ... not found in
   location global” means the region is wrong. Keep the `anthropic-vertex/` prefix
   on `models.*`/`--model`; a bare `claude-*` id hits the direct `anthropic`
   provider and fails.

## Step 4 — This pi session (orchestrator) itself
The eval wrappers pin the *subprocess* to a good region+model, but the session
running these `/skill:eval-*` commands uses ITS OWN default model + ambient
`CLOUD_ML_REGION`. On this project the models are region-split and `global` is
flaky (`claude-opus-4-8` → global; `claude-opus-4-6`/`claude-sonnet-4-6` →
us-east5). If the session defaults to `claude-opus-4-8` on `global`, the
orchestrator itself will hit intermittent 404s mid-run. Recommend the user
relaunch pinned to a reliable pair before running evals:
```bash
CLOUD_ML_REGION=us-east5 pi --model anthropic-vertex/claude-opus-4-6 --approve
```

## Step 5 — Report
Summarize PASS/FIX. When green, point to `/skill:eval-run` to run.
