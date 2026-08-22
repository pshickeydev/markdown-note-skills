#!/usr/bin/env bash
#
# Run any agent-eval-harness script with the correct cwd and environment,
# from the repo root — the Pi-native equivalent of the harness invoking its own
# ${CLAUDE_SKILL_DIR}/scripts/*.py. Used by the .pi/skills/eval-* orchestrators.
#
# Usage:
#   AGENT_EVAL_HARNESS=/path/to/agent-eval-harness \
#     eval/bin/harness.sh <relpath-under-harness> [args...]
#
# Examples:
#   eval/bin/harness.sh skills/eval-check/scripts/reference_checker.py --root . --format text
#   eval/bin/harness.sh skills/eval-compare/scripts/compare.py discover eval/runs/journal-note
#   eval/bin/harness.sh skills/eval-setup/scripts/check_env.py --config eval/journal-note/eval.yaml
#
# Prereqs: the harness cloned + `pip install -e` (so `agent_eval` imports), at
# the pinned tag v1.41.0.
#
set -euo pipefail

HARNESS="${AGENT_EVAL_HARNESS:-}"
[ -n "$HARNESS" ] || { echo "ERROR: set AGENT_EVAL_HARNESS to the harness checkout (v1.41.0)" >&2; exit 2; }

REL="${1:-}"
[ -n "$REL" ] || { echo "usage: harness.sh <relpath-under-harness> [args...]" >&2; exit 2; }
shift

SCRIPT="$HARNESS/$REL"
[ -f "$SCRIPT" ] || { echo "ERROR: harness script not found: $SCRIPT" >&2; exit 2; }

# Run from the repo root so config/dataset/run paths resolve consistently.
REPO_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../.." && pwd)"
cd "$REPO_ROOT"
export AGENT_EVAL_RUNS_DIR="${AGENT_EVAL_RUNS_DIR:-eval/runs}"

exec python3 "$SCRIPT" "$@"
