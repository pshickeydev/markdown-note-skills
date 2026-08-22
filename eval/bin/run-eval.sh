#!/usr/bin/env bash
#
# Pi-native driver for the agent-eval-harness pipeline — no Claude Code needed.
#
# The harness's `/eval-run` is a Claude Code plugin skill (it uses
# ${CLAUDE_SKILL_DIR}, the Skill/Agent tools, etc.), so it does not run in pi.
# But it is just a documented sequence of python3 script calls over the
# installed `agent_eval` package. This script reproduces that core sequence
#   workspace.py -> execute.py -> collect.py -> score.py -> report.py
# with pi as the runner (via eval/bin/run-skill.sh + eval/bin/run-judge.sh).
#
# Prereqs: the harness cloned + `pip install -e` (so `agent_eval` imports), pi
# authenticated for models.skill / models.judge, and python3 + git on PATH.
#
# Usage:
#   AGENT_EVAL_HARNESS=/path/to/agent-eval-harness \
#     eval/bin/run-eval.sh --config eval/journal-note/eval.yaml [options]
#
# Options:
#   --config <path>     eval.yaml to run (required)
#   --model <pattern>   skill model (default: models.skill from the config)
#   --cases <id...>     restrict to specific case ids (repeatable / space list)
#   --run-id <id>       run identifier (default: <date>-pi)
#   --no-llm-judges     deterministic judges only (skip the pi agent judges)
#   --baseline <id>     compare against a prior run (pairwise + regression)
#   --harness <dir>     harness checkout (default: $AGENT_EVAL_HARNESS)
#   --open              open the HTML report when finished
#
set -euo pipefail

CONFIG=""; MODEL=""; RUN_ID=""; BASELINE=""; HARNESS="${AGENT_EVAL_HARNESS:-}"
NO_LLM=0; OPEN=0
CASES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --config)   CONFIG="$2"; shift 2;;
    --model)    MODEL="$2"; shift 2;;
    --run-id)   RUN_ID="$2"; shift 2;;
    --baseline) BASELINE="$2"; shift 2;;
    --harness)  HARNESS="$2"; shift 2;;
    --no-llm-judges) NO_LLM=1; shift;;
    --open)     OPEN=1; shift;;
    --cases)    shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do
                  IFS=',' read -ra _c <<< "$1"; CASES+=("${_c[@]}"); shift; done;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2;;
  esac
done

[ -n "$CONFIG" ]  || { echo "ERROR: --config is required" >&2; exit 2; }
[ -n "$HARNESS" ] || { echo "ERROR: set --harness or AGENT_EVAL_HARNESS to the harness checkout" >&2; exit 2; }

# Absolute config path, then run from the repo root: workspace.py symlinks
# project resources from cwd, and PROJECT_ROOT (execution.env: $PWD) must be the
# repo so the runner resolves dataset fixtures.
CONFIG="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
REPO_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd)"
cd "$REPO_ROOT"

SC="$HARNESS/skills/eval-run/scripts"
[ -f "$SC/workspace.py" ] || { echo "ERROR: harness scripts not found under $SC (is --harness correct?)" >&2; exit 2; }

export AGENT_EVAL_RUNS_DIR="${AGENT_EVAL_RUNS_DIR:-eval/runs}"
EVAL_NAME="$(python3 -c 'import sys; from agent_eval.config import EvalConfig; print(EvalConfig.from_yaml(sys.argv[1]).eval_name())' "$CONFIG")"
RUN_ID="${RUN_ID:-$(date +%Y-%m-%d)-pi}"
OUT="$AGENT_EVAL_RUNS_DIR/$EVAL_NAME/$RUN_ID"

echo "== eval '$EVAL_NAME'  run-id '$RUN_ID'  config $CONFIG =="

# 1) Prepare per-case workspaces.
ws_args=(--config "$CONFIG" --run-id "$RUN_ID")
[ ${#CASES[@]} -gt 0 ] && ws_args+=(--cases "${CASES[@]}")
ws_log="$(mktemp)"
python3 "$SC/workspace.py" "${ws_args[@]}" | tee "$ws_log"
WS="$(awk '/^WORKSPACE:/{print $2}' "$ws_log")"; rm -f "$ws_log"
[ -n "$WS" ] || { echo "ERROR: workspace.py reported no WORKSPACE path" >&2; exit 1; }

# 2) Execute the skill per case (runner.type: cli -> run-skill.sh -> pi).
ex_args=(--config "$CONFIG" --workspace "$WS" --output "$OUT" --run-id "$RUN_ID")
[ -n "$MODEL" ] && ex_args+=(--model "$MODEL")
python3 "$SC/execute.py" "${ex_args[@]}"

# 3) Collect artifacts into per-case dirs.
python3 "$SC/collect.py" --config "$CONFIG" --workspace "$WS" --output "$OUT"

# 4) Score: deterministic checks always; pi agent judges unless --no-llm-judges.
sc_args=(judges --run-id "$RUN_ID" --config "$CONFIG" --workspace "$WS")
[ "$NO_LLM" -eq 1 ] && sc_args+=(--no-llm-judges)
python3 "$SC/score.py" "${sc_args[@]}"

# 4b) Optional baseline comparison.
if [ -n "$BASELINE" ]; then
  python3 "$SC/score.py" pairwise   --run-id "$RUN_ID" --baseline "$BASELINE" --config "$CONFIG" || true
  python3 "$SC/score.py" regression --run-id "$RUN_ID" --baseline "$BASELINE" --config "$CONFIG" || true
fi

# 5) HTML report.
rp_args=(--run-id "$RUN_ID" --config "$CONFIG")
[ -n "$BASELINE" ] && rp_args+=(--baseline "$BASELINE")
[ "$OPEN" -eq 1 ] && rp_args+=(--open)
python3 "$SC/report.py" "${rp_args[@]}"

echo "== done =="
echo "   summary: $OUT/summary.yaml"
echo "   report:  $OUT/report.html"
