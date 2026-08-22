#!/usr/bin/env bash
#
# Opaque CLI runner wrapper for agent-eval-harness (runner.type: cli).
#
# The harness invokes this once per test case with placeholders substituted
# from eval.yaml (see docs/opaque-cli-runner-contract.md in the harness repo).
# Expected invocation (from each eval.yaml `runner.command`):
#
#   eval/bin/run-skill.sh <skill> <workspace> <output_dir> <model> <system_prompt>
#
# What it does:
#   1. Reads the case `input.yaml` from the workspace.
#   2. Stages a throwaway copy of the vault fixture, the skills, an AGENTS.md,
#      and a nested git repo under <workspace>/.work/run/ (collect.py ignores
#      the .work prefix, so this scaffolding never leaks into judge inputs).
#   3. The staged AGENTS.md's `## Vault Location` points at the staged vault,
#      so the skill resolves `{vault}` to the fixture via every path (skill-
#      relative ../../../AGENTS.md, git root, and cwd).
#   4. Invokes the agent CLI headlessly (cwd=.work/run) with a natural-language
#      directive to read and follow the staged skill (not pi's /skill: syntax,
#      which only works interactively).
#   5. Copies the resulting journals/, summaries/, topics/ into <workspace>/artifacts
#      (the outputs.path dir) so collect.py and the judges can read them. Note:
#      the dir is NOT named "output" — agent-judge staging reserves that name.
#   6. Parses pi's JSON event stream into <output_dir>/metrics.json (real token
#      usage + cost + per-model breakdown). For a custom AGENT_EVAL_CLI, writes
#      a minimal metrics.json (model only).
#
# The runner is pi by default. To use a different agent, set AGENT_EVAL_CLI to a
# command template that runs your agent in headless mode with the staged skill
# loaded. The template supports these tokens (all substituted before exec):
#
#   {prompt}         the "use the <skill> skill … Input arguments: <args>" directive (passed as an arg; stdin closed)
#   {model}          the model id/pattern chosen for the run
#   {system_prompt}  non-interactive + vault-scoping guidance built by this wrapper
#   {cwd}            the workspace directory (agent runs with this as cwd)
#   {skills}         the workspace copy of the skills dir (agent MUST load from here)
#   {skill_dir}      the staged directory of the skill under test ({skills}/<skill>)
#
# Default (pi):
#   pi --mode json --no-session --approve --no-context-files --no-skills \
#      --no-extensions -e <anthropic-vertex plugin path> \
#      --skill {skill_dir} --model {model} \
#      --append-system-prompt {system_prompt} {prompt}
#   (loads ONLY the anthropic-vertex provider plugin; path from
#    AGENT_EVAL_PI_EXTENSION or ~/.pi/agent/npm/node_modules/@twogiants/pi-anthropic-vertex)
# (--mode json streams events so we can extract real token/cost metrics.)
# Example override (Claude Code):
#   export AGENT_EVAL_CLI='claude --print --model {model} --plugin-dir {skills} --append-system-prompt "{system_prompt}" "{prompt}"'
#
# SAFETY: these skills resolve the vault from AGENTS.md, checking the copy
# ../../../AGENTS.md next to the SKILL.md file (and the git root) BEFORE the
# cwd. If your agent loads skills from the real repo, the skill will resolve
# the *real* vault in the repo's AGENTS.md and mutate it. This wrapper stages
# an isolated skills copy + git repo + AGENTS.md in the workspace so all three
# resolution paths point at the fixture; point your agent at {skill_dir} (or
# {skills} for the whole set). pi does this via --skill {skill_dir}.
#
set -euo pipefail

SKILL="${1:?skill name required}"
WORKSPACE="${2:?workspace path required}"
OUTPUT_DIR="${3:?output dir required}"
MODEL="${4:-}"
SYSTEM_PROMPT_IN="${5:-}"

log() { printf '%s\n' "$*" >&2; }

# --- resolve the anthropic-vertex provider plugin --------------------------
# The Vertex-hosted Anthropic models come from a pi plugin
# (npm:@twogiants/pi-anthropic-vertex). We load ONLY that plugin (via -e) with
# --no-extensions, so the model resolves but no other extensions (e.g. an
# interactive ask-user-question plugin) can interfere with a headless run.
# Override the path with AGENT_EVAL_PI_EXTENSION. Load it by absolute path
# (the `-e npm:<pkg>` form re-resolves and drops the plugin's auth config).
pi_ext() {
  if [ -n "${AGENT_EVAL_PI_EXTENSION:-}" ]; then printf '%s' "$AGENT_EVAL_PI_EXTENSION"; return; fi
  local d="$HOME/.pi/agent/npm/node_modules/@twogiants/pi-anthropic-vertex"
  [ -d "$d" ] && printf '%s' "$d"
}

# The anthropic-vertex plugin selects its Vertex region from CLOUD_ML_REGION
# (then ANTHROPIC_VERTEX_REGION, then GOOGLE_CLOUD_LOCATION). The "global"
# location intermittently 404s for Claude models, which kills multi-call skill
# runs mid-way. Force a real region when the ambient one is unset or "global".
# Override with AGENT_EVAL_VERTEX_REGION (default us-east5, the plugin's default).
if [ -z "${CLOUD_ML_REGION:-}" ] || [ "${CLOUD_ML_REGION:-}" = "global" ]; then
  export CLOUD_ML_REGION="${AGENT_EVAL_VERTEX_REGION:-us-east5}"
fi

# --- locate project root (source of dataset fixtures) ----------------------
# PROJECT_ROOT is injected by eval.yaml execution.env (resolved from $PWD at
# the time /eval-run was launched). Fall back to this script's own location:
# it lives at <root>/eval/bin/run-skill.sh, so <root> is two dirs up. This is
# robust regardless of the cwd the harness runs us in.
SELF_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SELF_DIR/../.." && pwd)}"

# Canonicalize to absolute paths so the vault location written into AGENTS.md
# is always absolute (the skills normalize/expand vault paths; an absolute path
# removes any ambiguity about what they resolve relative to).
mkdir -p "$WORKSPACE" "$OUTPUT_DIR"
WORKSPACE="$(cd "$WORKSPACE" && pwd -P)"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd -P)"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"
cd "$WORKSPACE"

# Canonical repo root (resolve symlinks) so we copy the real skill files.
REPO_SKILLS="$PROJECT_ROOT/.agents/skills"

# All scaffolding (fixture vault, staged skills, AGENTS.md, nested git repo)
# lives under .work/ — collect.py's _HARNESS_PATHS ignores that prefix, so none
# of it is swept into the case's _modified files and rendered into judge
# prompts. Only the results copied to $WORKSPACE/artifacts are collected.
STAGE="$WORKSPACE/.work/run"
rm -rf "$STAGE"
mkdir -p "$STAGE"

INPUT_YAML="$WORKSPACE/input.yaml"
[ -f "$INPUT_YAML" ] || { log "ERROR: no input.yaml in workspace $WORKSPACE"; exit 2; }

# --- read fields from input.yaml (fixture, args) ---------------------------
read_field() {
  python3 - "$INPUT_YAML" "$1" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1])) or {}
val = data.get(sys.argv[2], "")
print(val if val is not None else "")
PY
}

FIXTURE_REL="$(read_field fixture)"
SKILL_ARGS="$(read_field args)"

# --- stage the vault fixture -----------------------------------------------
VAULT="$STAGE/vault"
mkdir -p "$VAULT"
if [ -n "$FIXTURE_REL" ]; then
  FIXTURE_ABS="$PROJECT_ROOT/$FIXTURE_REL"
  [ -d "$FIXTURE_ABS" ] || { log "ERROR: fixture dir not found: $FIXTURE_ABS"; exit 2; }
  cp -R "$FIXTURE_ABS/." "$VAULT/"
fi
log "Staged vault fixture from '${FIXTURE_REL:-<empty>}' into $VAULT"

# --- isolate skills so vault resolution can't reach the real vault ---------
# The skills check ../../../AGENTS.md relative to SKILL.md and the git root
# before cwd. Stage a private copy of the skills and an AGENTS.md at the root
# of the .work/run staging dir, and make that dir its own git repo, so every
# resolution path lands on the fixture vault below.
if [ -d "$REPO_SKILLS" ]; then
  mkdir -p "$STAGE/.agents"
  cp -RL "$REPO_SKILLS" "$STAGE/.agents/skills"
  # Convenience symlink some agents look for.
  ln -sfn ../.agents/skills "$STAGE/.claude/skills" 2>/dev/null || \
    { mkdir -p "$STAGE/.claude"; ln -sfn ../.agents/skills "$STAGE/.claude/skills" 2>/dev/null || true; }
fi
git init -q "$STAGE" 2>/dev/null || true

# --- write AGENTS.md so the skill resolves {vault} to the staged copy ------
# Placed at the staging root: this is ../../../AGENTS.md for the staged skills,
# the git-root AGENTS.md, and the cwd ./AGENTS.md — all at once.
cat > "$STAGE/AGENTS.md" <<EOF
# AGENTS.md (eval harness — generated per case)

## Vault Location

$VAULT
EOF

# Safety warning: detect a real repo AGENTS.md pointing outside the workspace.
if [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
  REAL_VAULT="$(awk '/^## Vault Location/{f=1;next} f&&NF{gsub(/[`"'"'"']/,"");print;exit}' "$PROJECT_ROOT/AGENTS.md" 2>/dev/null || true)"
  case "$REAL_VAULT" in
    "$WORKSPACE"*|"") : ;;
    *) log "WARNING: repo AGENTS.md points at '$REAL_VAULT'. Ensure your agent loads skills from {skill_dir} ($STAGE/.agents/skills/$SKILL) so it does NOT touch that vault." ;;
  esac
fi

# --- compose the agent prompt ----------------------------------------------
# NOT pi's `/skill:<name>` syntax: slash commands are an interactive-mode
# feature and are not expanded under --print/--mode json. Instead give an
# explicit natural-language directive so the model reliably reads and follows
# the staged skill (pi's docs note models don't always load a skill on their
# own). The skill under test is the only one loaded (--skill {skill_dir}).
PROMPT="Use the $SKILL skill: read its SKILL.md and follow its procedure exactly to complete this request. Input arguments: $SKILL_ARGS"
SYSTEM_PROMPT="${SYSTEM_PROMPT_IN:-}"
# Always enforce non-interactive behaviour: these skills have confirmation
# gates that would otherwise block a headless run.
NONINTERACTIVE="Non-interactive evaluation run. Never ask the user to confirm or clarify, and never stop to wait for input. EXECUTE the entire procedure yourself using tool calls (read, then edit/write) — do NOT merely describe, plan, or narrate the steps. Keep going turn after turn, calling tools, until the task is fully complete and the target file(s) have actually been created or edited on disk; only end your turn once the work is done. The Obsidian vault for this run is EXACTLY '$VAULT'. Use only that vault. Ignore any other AGENTS.md or vault location you may find elsewhere; do not read, write, or resolve any vault outside '$VAULT'."
if [ -n "$SYSTEM_PROMPT" ]; then
  SYSTEM_PROMPT="$SYSTEM_PROMPT

$NONINTERACTIVE"
else
  SYSTEM_PROMPT="$NONINTERACTIVE"
fi

# --- invoke the agent ------------------------------------------------------
SKILL_DIR="$STAGE/.agents/skills/$SKILL"
PI_EXT="$(pi_ext)"

# Signature of the vault's file contents — used to detect whether the run
# actually did anything (all three skills always modify the vault).
vault_sig() { find "$VAULT" -type f -exec md5sum {} + 2>/dev/null | sort | md5sum; }

# One agent invocation. Sets AGENT_EXIT; for the default pi path also captures
# the JSON event stream and parses metrics.json.
invoke_agent() {
  set +e
  if [ -n "${AGENT_EVAL_CLI:-}" ]; then
    # Custom agent override: a template string, shell-parsed via eval. The
    # template is responsible for its own quoting.
    local CMD="$AGENT_EVAL_CLI"
    CMD="${CMD//\{prompt\}/$PROMPT}"
    CMD="${CMD//\{model\}/$MODEL}"
    CMD="${CMD//\{system_prompt\}/$SYSTEM_PROMPT}"
    CMD="${CMD//\{cwd\}/$STAGE}"
    CMD="${CMD//\{skill_dir\}/$SKILL_DIR}"
    CMD="${CMD//\{skills\}/$STAGE/.agents/skills}"
    ( cd "$STAGE" && eval "$CMD" ) < /dev/null
    AGENT_EXIT=$?
  else
    # Default pi: build the argv as an ARRAY and run pi directly — NO eval, so
    # quotes/newlines/special chars in the prompt, args, or system prompt are
    # passed verbatim as single arguments (e.g. a note containing a " won't
    # break the command). --no-context-files stops auto-loading any AGENTS.md
    # (the skill reads the workspace one via file tools); --no-skills disables
    # other skill discovery (explicit --skill still loads); --no-extensions -e
    # loads ONLY the anthropic-vertex provider plugin. --mode json streams
    # events (usage/cost) captured under .work and parsed into metrics.json.
    local PI_ARGS=(--mode json --no-session --approve --no-context-files --no-skills)
    if [ -n "$PI_EXT" ]; then
      PI_ARGS+=(--no-extensions -e "$PI_EXT")
    else
      log "WARNING: anthropic-vertex plugin not found; loading all extensions. Set AGENT_EVAL_PI_EXTENSION to its path for a hermetic run."
    fi
    PI_ARGS+=(--skill "$SKILL_DIR" --model "$MODEL" --append-system-prompt "$SYSTEM_PROMPT" "$PROMPT")
    ( cd "$STAGE" && pi "${PI_ARGS[@]}" ) < /dev/null > "$STAGE/pi-events.jsonl" 2> "$STAGE/pi-stderr.log"
    AGENT_EXIT=$?
    cat "$STAGE/pi-stderr.log" >&2 2>/dev/null || true
    python3 "$SELF_DIR/pi-metrics.py" "$STAGE/pi-events.jsonl" "$OUTPUT_DIR/metrics.json" "$MODEL" || true
  fi
  set -e
}

# Headless multi-step runs are non-deterministic: the model sometimes narrates
# a step and ends its turn (pi's loop stops on a tool-less message) without
# actually editing the vault. Since a successful run ALWAYS changes the vault,
# retry when nothing changed (the fixture is still pristine, so a retry is
# clean). Bounded by AGENT_EVAL_MAX_ATTEMPTS (default 3).
MAX_ATTEMPTS="${AGENT_EVAL_MAX_ATTEMPTS:-3}"
SIG_BEFORE="$(vault_sig)"
attempt=1
while :; do
  log "Invoking agent for skill '$SKILL' (attempt $attempt/$MAX_ATTEMPTS): $PROMPT"
  invoke_agent
  if [ "$(vault_sig)" != "$SIG_BEFORE" ]; then
    break                       # the run changed the vault — done (judges assess quality)
  fi
  if [ "$attempt" -ge "$MAX_ATTEMPTS" ]; then
    log "WARNING: agent produced no vault changes after $attempt attempt(s); giving up."
    break
  fi
  log "Attempt $attempt made no changes to the vault; retrying."
  attempt=$((attempt + 1))
done
log "Agent exited with code $AGENT_EXIT"

# --- collect vault outputs into the outputs.path dir ("artifacts") ----------
# NOT {output_dir}: that dir is named "output", which agent-judge staging
# reserves for the verdict file and skips when staging case artifacts.
ARTIFACTS="$WORKSPACE/artifacts"
mkdir -p "$ARTIFACTS"
for sub in journals summaries topics; do
  if [ -d "$VAULT/$sub" ]; then
    mkdir -p "$ARTIFACTS/$sub"
    cp -R "$VAULT/$sub/." "$ARTIFACTS/$sub/" 2>/dev/null || true
  fi
done

# --- fallback metrics.json (custom-agent path, or if parsing produced none) --
if [ ! -f "$OUTPUT_DIR/metrics.json" ]; then
  printf '{"model": "%s"}\n' "$MODEL" > "$OUTPUT_DIR/metrics.json"
fi

exit "$AGENT_EXIT"
