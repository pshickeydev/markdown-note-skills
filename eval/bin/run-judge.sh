#!/usr/bin/env bash
#
# Opaque CLI runner wrapper for AGENT JUDGES (agent.runner.type: cli).
#
# The harness stages an isolated judge workspace (the case's artifacts under
# ./artifacts, a writable ./output for the verdict), then runs an agent judge
# through the runner abstraction in prompt mode:
#
#   runner.execute(target=None, args=<rendered rubric + output contract>, ...)
#
# For the opaque cli runner that becomes this command, invoked with cwd set to
# the judge workspace:
#
#   run-judge.sh <output_dir> <model> <full_prompt>
#
# It runs the judge through pi (same authentication as the skill runner), so no
# separate ANTHROPIC_API_KEY is needed. pi reads the staged artifacts (also
# inlined into the prompt via {{ outputs }}) and writes its verdict to
# ./output/score.json per the harness-appended contract; if it prints the JSON
# to stdout instead, the harness parses that as a fallback.
#
# The judge model is a Vertex model from the anthropic-vertex plugin, so we load
# ONLY that plugin (no other extensions) — same as the skill runner.
# Override the judge binary with AGENT_EVAL_JUDGE_CLI (defaults to "pi") and the
# plugin path with AGENT_EVAL_PI_EXTENSION.
#
set -euo pipefail

OUTPUT_DIR="${1:?output dir required}"
MODEL="${2:?model required}"
PROMPT="${3:?prompt required}"

mkdir -p "$OUTPUT_DIR"

JUDGE_BIN="${AGENT_EVAL_JUDGE_CLI:-pi}"

# The anthropic-vertex plugin uses CLOUD_ML_REGION; "global" 404s for Claude
# models. Force a real region when the ambient one is unset or "global".
# Override with AGENT_EVAL_VERTEX_REGION (default us-east5).
if [ -z "${CLOUD_ML_REGION:-}" ] || [ "${CLOUD_ML_REGION:-}" = "global" ]; then
  export CLOUD_ML_REGION="${AGENT_EVAL_VERTEX_REGION:-us-east5}"
fi

# Load only the anthropic-vertex provider plugin (by absolute path; the
# `-e npm:<pkg>` form drops its auth config). Fall back to normal discovery if
# it can't be found.
EXT=(--no-extensions)
PI_EXT="${AGENT_EVAL_PI_EXTENSION:-}"
[ -z "$PI_EXT" ] && [ -d "$HOME/.pi/agent/npm/node_modules/@twogiants/pi-anthropic-vertex" ] \
  && PI_EXT="$HOME/.pi/agent/npm/node_modules/@twogiants/pi-anthropic-vertex"
if [ -n "$PI_EXT" ]; then EXT=(--no-extensions -e "$PI_EXT"); else EXT=(); fi

# The prompt is passed as a single argv element (no shell re-parsing), so its
# embedded quotes/newlines/JSON examples survive intact. Read + Write let pi
# inspect ./artifacts and write ./output/score.json; stdin is closed so a
# print-mode run never blocks.
exec "$JUDGE_BIN" \
  --print \
  --no-session \
  --approve \
  --no-context-files \
  --no-skills \
  ${EXT[@]+"${EXT[@]}"} \
  --tools read,write \
  --model "$MODEL" \
  "$PROMPT" < /dev/null
