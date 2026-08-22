# Evaluations

This directory wires the [agent-eval-harness](https://github.com/opendatahub-io/agent-eval-harness)
to the three journal skills so their behavior can be measured and regression-tested.

## Harness version (pinned)

Verified against **agent-eval-harness `v1.41.0`** (release commit `2a10e504`).
This config depends on harness internals that are **not a stable public API**, so
treat the version as pinned:

- agent judges running through the `cli` runner (so judges use pi's auth),
- the `output` / `.context` names being reserved by agent-judge staging (why our
  output dir is `artifacts`),
- `.work/` being ignored by `collect.py` (keeps our scaffolding out of judges),
- the `{config_dir}` placeholder and `{{ outputs }}` rendering.

**Install that exact version (reproducible pin):**

```bash
git clone https://github.com/opendatahub-io/agent-eval-harness
cd agent-eval-harness && git checkout v1.41.0 && pip install -e .
claude --plugin-dir .        # loads the /eval-* skills at this version
```

The marketplace install (`agent-eval-harness@opendatahub-skills`) always tracks
the latest release and is **not** pinned — use the git-clone + `git checkout`
above when you need reproducibility.

**Upgrading:** check out a newer tag, re-run the smoke test
(`/eval-run --config eval/journal-note/eval.yaml --cases 001-append-existing`),
and only then bump the version recorded here. The harness CHANGELOG flags changes
to runners, judges, and artifact collection — the coupling points above.

## Layout

```
eval/
  bin/run-skill.sh                 opaque CLI runner wrapper (skill runs, via pi)
  bin/run-judge.sh                 opaque CLI runner wrapper (agent judges, via pi)
  bin/pi-metrics.py                parses pi's JSON stream -> metrics.json (tokens/cost)
  bin/run-eval.sh                  Pi-native pipeline driver (workspace->execute->collect->score->report)
  bin/harness.sh                   runs any harness script with the right cwd/env (backbone for the orchestrators)
  journal-note/
    eval.yaml                      config for the journal-note skill
    dataset/cases/*/               test cases (input.yaml, fixture vault, reference/, annotations.yaml)
  journal-organize/
    eval.yaml
    dataset/cases/*/
  journal-weekly/
    eval.yaml
    dataset/cases/*/
```

The Pi **orchestrator** skills live outside `eval/` (in `.pi/skills/`) so the
runner never copies them into a test workspace. They mirror the harness's
Claude-Code `/eval-*` plugin commands, but are built for pi:

```
.pi/skills/eval-run/       /skill:eval-run       run eval(s) + interpret results   (-> run-eval.sh)
.pi/skills/eval-setup/     /skill:eval-setup     preflight env + pi auth           (-> check_env.py)
.pi/skills/eval-analyze/   /skill:eval-analyze   author / validate an eval.yaml     (-> validate_eval.py)
.pi/skills/eval-dataset/   /skill:eval-dataset   add / generate test cases
.pi/skills/eval-review/    /skill:eval-review    human review of a run -> review.yaml
.pi/skills/eval-optimize/  /skill:eval-optimize  run -> diagnose -> edit -> re-run
.pi/skills/eval-compare/   /skill:eval-compare   HTML comparison across runs        (-> compare.py)
.pi/skills/eval-check/     /skill:eval-check     config/reference health scan       (-> reference_checker.py)
.pi/skills/eval-mlflow/    /skill:eval-mlflow    log results / feedback to MLflow   (-> log_results.py)
.pi/skills/eval-anova/     /skill:eval-anova     matrix DoE + ANOVA (advanced)      (-> orchestrate.py)
```

Script-backed stages call harness scripts through `eval/bin/harness.sh`;
agent-driven stages (`eval-review`, `eval-optimize`, and the authoring parts of
`eval-analyze`/`eval-dataset`) are procedures that reuse `run-eval.sh`. All
require `AGENT_EVAL_HARNESS` to point at the pinned harness checkout and are
discovered by pi once the project is trusted (`pi --approve`).

Each case is self-contained:

| File | Purpose |
|------|---------|
| `input.yaml` | `args` (skill arguments), `fixture` (repo-relative vault dir), `target` (file the skill writes) |
| `vault/` | throwaway Obsidian vault fixture — `templates/`, `journals/`, and sometimes `topics/` |
| `reference/` | example gold-standard output (illustrative; the quality judge is reference-free) |
| `annotations.yaml` | expected bullets / headings / invariants for the deterministic judges |

## Runner model

These skills operate on an Obsidian vault located via `AGENTS.md` (`## Vault Location`),
so the harness can't run them directly. The configs use the **opaque `cli` runner**
(`runner.type: cli`) pointing at `eval/bin/run-skill.sh`, which per case:

1. stages the case's `fixture` vault, the skills, and an `AGENTS.md` under
   `.work/run/` (see the **Vault isolation** section below),
2. points that `AGENTS.md`'s `## Vault Location` at the staged vault,
3. invokes your agent headlessly (cwd `.work/run`) with a natural-language
   directive to read and follow the staged skill (pi's `/skill:` command syntax
   only works interactively, so it isn't used here),
4. copies the resulting `journals/ summaries/ topics/` into the `artifacts/`
   output dir for the judges (**not** `output/` — agent-judge staging reserves
   that name for the verdict file),
5. parses pi's JSON event stream into `metrics.json` (real token usage, cost,
   and per-model breakdown; see below).

The `runner.command` uses the `{config_dir}` placeholder (absolute) because the
harness runs the command with its cwd set to the case workspace, where a
repo-relative path would not resolve.

### Runner: pi (default)

The wrapper drives [pi](https://github.com/earendil-works/pi-coding-agent) out of
the box — no configuration needed. For each case it runs, effectively:

```bash
pi --mode json --no-session --approve --no-context-files --no-skills --no-extensions \
   --skill {skill_dir} --model {model} \
   --append-system-prompt {system_prompt} {prompt}
```

Why these flags:

| Flag | Purpose |
|------|---------|
| `--mode json` | Non-interactive: stream all events as JSON and exit. The wrapper captures the stream (kept under `.work/`, out of the collected artifacts), extracts real token usage + cost into `metrics.json` via `eval/bin/pi-metrics.py`, and surfaces the final assistant text as `stdout.log`. |
| `--no-session` | Ephemeral — don't persist a session file per case. |
| `--approve` | Trust the staged project-local skill files (avoids a trust prompt that would hang a headless run). |
| `--no-context-files` | Do **not** auto-load any `AGENTS.md`/`CLAUDE.md` into context. The skill still reads the workspace `AGENTS.md` itself via file tools; this just stops the *real* repo `AGENTS.md` from leaking into context. |
| `--no-skills` / `--no-extensions` | Disable discovery of other global/project skills and extensions; the explicit `--skill` still loads (additive). Keeps runs hermetic and stops an interactive "ask" extension from hanging a headless run. |
| `--skill {skill_dir}` | Load **only** the staged skill under test (`{workspace}/.work/run/.agents/skills/<skill>`). |
| `--model {model}` | The model **id** from `models.skill` / `--model`. Use a `provider/id` so pi picks the right provider. |

**Provider matters.** The configs pin models to Vertex with an
`anthropic-vertex/` prefix (`anthropic-vertex/claude-sonnet-4-6`,
`anthropic-vertex/claude-opus-4-6`). Without the prefix, pi resolves the bare id
to the **direct `anthropic` provider** and the run fails asking for Anthropic
auth. Pick a model with `/eval-run --model anthropic-vertex/claude-sonnet-4-6`
(keep the prefix); it overrides `models.skill`. On a different provider, change
the prefix (e.g. `anthropic/…` for the direct API, or a `google-vertex/…` model).

**The `anthropic-vertex` provider is a pi plugin**
(`npm:@twogiants/pi-anthropic-vertex`). The wrappers load **only** that plugin
(`--no-extensions -e <plugin path>`) — so the model resolves, but no other
extension (e.g. an interactive `ask-user-question` plugin) can hang a headless
run. Set `AGENT_EVAL_PI_EXTENSION` to override the plugin path (default:
`~/.pi/agent/npm/node_modules/@twogiants/pi-anthropic-vertex`).

**Region matters (this bites).** The plugin picks its Vertex region from
`CLOUD_ML_REGION` (then `ANTHROPIC_VERTEX_REGION`, then `GOOGLE_CLOUD_LOCATION`).
The `global` location **intermittently 404s** for Claude models — a single call
may succeed, but a multi-call skill run usually dies partway (`stopReason:
error`, "model ... not found ... in location global"), producing an empty run.
The wrappers force a real region when the ambient one is unset or `global`
(default **`us-east5`**, the plugin's own default); override with
`AGENT_EVAL_VERTEX_REGION`. If your models live in another region, set it.

On this project the models are **region-split** and `global` is unreliable:
`claude-opus-4-6` / `claude-sonnet-4-6` are in **`us-east5`**, while a newer
`claude-opus-4-8` is only in `global`. The eval configs use the `us-east5` pair.

> **The orchestrator session needs this too.** The wrappers fix the eval
> *subprocess*, but when you drive evals from a pi session (`/skill:eval-*`),
> that session uses *its own* default model + ambient `CLOUD_ML_REGION`. If it
> defaults to `claude-opus-4-8` on `global` you'll hit intermittent 404s.
> Launch it pinned to a reliable pair, e.g.
> `CLOUD_ML_REGION=us-east5 pi --model anthropic-vertex/claude-opus-4-6 --approve`.

### Judges: same authentication as the runner

The `*_quality` judges are **agent judges** (`agent:` blocks): instead of the
harness's built-in Anthropic client, each runs *through the runner abstraction*
via `eval/bin/run-judge.sh`, which invokes **pi** — so judges authenticate
exactly like the skill run. No separate `ANTHROPIC_API_KEY` is needed.

The harness stages an isolated judge workspace (the case artifacts under
`artifacts/`, a writable `output/`), renders the rubric (the generated files are
inlined via `{{ outputs }}`), and appends a contract telling pi to write its
verdict to `./output/score.json` (`{"score": <1-5>, "rationale": "..."}`); if pi
prints the JSON to stdout instead, the harness parses that as a fallback. The
judges are **reference-free** — they grade the output on its own merits, so no
per-case gold file needs to be staged. Override the judge binary with
`AGENT_EVAL_JUDGE_CLI` (defaults to `pi`).

### Metrics (tokens & cost)

Because the default runner uses `pi --mode json`, each run records **real** token
usage, cost, `num_turns`, and a per-model breakdown in `metrics.json` — so the
harness report's cost/token columns and any `cost_budget` judge work as intended.
(pi reports both tokens and per-message cost, including cache read/write, in its
`usage` objects.) A custom `AGENT_EVAL_CLI` only gets a model-only `metrics.json`
unless its command writes its own `{output_dir}/metrics.json`.

### Using a different agent

Set `AGENT_EVAL_CLI` to a command template to override the default. Supported
tokens: `{prompt}`, `{model}`, `{system_prompt}`, `{cwd}`, `{skills}`,
`{skill_dir}`. The template must pass `{prompt}` as an argument (stdin is closed).
Its stdout/stderr flow to the harness logs as-is (no JSON metrics parsing).

```bash
# Claude Code
export AGENT_EVAL_CLI='claude --print --model {model} --plugin-dir {skills} --append-system-prompt "{system_prompt}" "{prompt}"'
```

## ⚠️ Vault isolation (read this)

The skills resolve the vault from `AGENTS.md`, and they check the copy at
`../../../AGENTS.md` **relative to the `SKILL.md` file** (and the git root)
*before* the current directory. This repo's own `AGENTS.md` points at your real
Obsidian vault. So if your agent runs the skill files **from the real repo**,
an eval will read and **write your real vault** instead of the fixture.

To prevent that, `run-skill.sh` builds an isolated environment per case under
`{workspace}/.work/run/` (the `.work` prefix keeps this scaffolding out of the
case's collected/modified files, so it never reaches the judges):

- copies the skills into `.work/run/.agents/skills` (exposed as `{skills}`;
  the skill under test is `{skill_dir}`),
- `git init`s `.work/run`, and
- writes `.work/run/AGENTS.md` pointing at the fixture,

so all three resolution paths (skill-relative `../../../AGENTS.md`, git root,
and cwd) land on the throwaway fixture. **Your `AGENT_EVAL_CLI` must load the
skill from `{skill_dir}`** (or `{skills}`), e.g. Claude Code:

```bash
export AGENT_EVAL_CLI='claude --print --model {model} --plugin-dir {skills} --append-system-prompt "{system_prompt}" "{prompt}"'
```

The wrapper also injects an authoritative vault path into the system prompt and
prints a `WARNING` if the repo `AGENTS.md` points outside the workspace. Do a
dry run against a throwaway `## Vault Location` the first time to confirm your
agent honours the isolation before trusting it near a real vault.

## Running

The harness's own `/eval-*` commands are a **Claude Code plugin** (they use
`${CLAUDE_SKILL_DIR}`, the `Skill`/`Agent` tools, etc.). You have three ways to
drive the pipeline; all use pi as the runner/judge.

### A. Pi as orchestrator *and* runner (no Claude Code)

Pi drives everything via the `eval-run` skill in `.pi/skills/`. Launch pi at the
repo root with the harness path exported, then ask it to run an eval:

```bash
export AGENT_EVAL_HARNESS=/path/to/agent-eval-harness   # cloned + pip install -e, at v1.41.0
cd /path/to/markdown-note-skills
pi --approve          # trust the project so .pi/skills/ loads
# then, in the session:
#   /skill:eval-run journal-note --no-llm-judges
#   /skill:eval-run all
#   "run the journal-weekly eval against anthropic-vertex/claude-sonnet-4-6"
```

The `eval-run` skill picks the config(s), checks pi auth, runs
`eval/bin/run-eval.sh`, and interprets `summary.yaml` against the thresholds.
The full stage suite is available the same way — a typical loop:

```
/skill:eval-setup                              # verify tooling + pi auth
/skill:eval-run journal-note --no-llm-judges   # fast structural pass
/skill:eval-run journal-note                   # full run (with the pi agent judge)
/skill:eval-review --run-id <id>               # inspect scores / failures
/skill:eval-optimize journal-note              # diagnose -> edit skill -> re-run vs baseline
/skill:eval-compare eval/runs/journal-note     # compare runs/models
/skill:eval-check                              # config/reference health scan
```

`eval-analyze` / `eval-dataset` maintain the configs and cases; `eval-mlflow`
and `eval-anova` are optional (they need the harness `[mlflow]` / `[anova]`
extras).

### B. Direct driver (scriptable, no agent at all)

`eval/bin/run-eval.sh` reproduces the harness pipeline
(workspace → execute → collect → score → report) as plain `python3` calls:

```bash
export AGENT_EVAL_HARNESS=/path/to/agent-eval-harness
eval/bin/run-eval.sh --config eval/journal-note/eval.yaml --no-llm-judges     # fast, free
eval/bin/run-eval.sh --config eval/journal-note/eval.yaml --model anthropic-vertex/claude-sonnet-4-6
eval/bin/run-eval.sh --config eval/journal-weekly/eval.yaml --cases 001-basic-week
```

Outputs land in `eval/runs/<eval-name>/<run-id>/` (`summary.yaml`, `report.html`).

### C. Claude Code as orchestrator (pi still runs the models)

If you do have the harness loaded as a Claude Code plugin, its `/eval-run` works
too — our `runner: cli` wrapper still shells out to pi for every skill/judge call:

```bash
/eval-run --config eval/journal-note/eval.yaml     --model anthropic-vertex/claude-sonnet-4-6
/eval-run --config eval/journal-organize/eval.yaml --model anthropic-vertex/claude-sonnet-4-6
/eval-run --config eval/journal-weekly/eval.yaml   --model anthropic-vertex/claude-sonnet-4-6
```

Both the skill run **and** the `*_quality` judges go through **pi**, so a single
set of Vertex credentials covers everything (Google Application Default
Credentials — `gcloud auth application-default login` — plus the Vertex project).
There is no separate judge credential, and `ANTHROPIC_API_KEY` is **not** used:
the `anthropic-vertex/` prefix keeps runs off the direct Anthropic API. Note
`pi auth check --provider anthropic-vertex` reports `provider_not_found` (it
doesn't recognize plugin providers) even when runs work — verify readiness with
a tiny real call instead (`/skill:eval-setup` does this).

Deterministic judges (`check:`) run without any API key and enforce the hard
invariants (note appended, content preserved, headings added, journals never
modified). The `*_quality` agent judges make model calls; skip them with
`--no-llm-judges` to run the deterministic judges only.

## Environment variables

| Var | Used by | Purpose |
|-----|---------|---------|
| `AGENT_EVAL_HARNESS` | `run-eval.sh`, `harness.sh` | Path to the harness checkout (v1.41.0). Required for the drivers. |
| `AGENT_EVAL_VERTEX_REGION` | `run-skill.sh`, `run-judge.sh` | Vertex region for the anthropic-vertex plugin (default `us-east5`; only applied when the ambient `CLOUD_ML_REGION` is unset or `global`). |
| `AGENT_EVAL_PI_EXTENSION` | `run-skill.sh`, `run-judge.sh` | Path to the anthropic-vertex plugin (default `~/.pi/agent/npm/node_modules/@twogiants/pi-anthropic-vertex`). |
| `AGENT_EVAL_MAX_ATTEMPTS` | `run-skill.sh` | Retries when a run leaves the vault unchanged (default `3`). |
| `AGENT_EVAL_CLI` / `AGENT_EVAL_JUDGE_CLI` | wrappers | Override the skill / judge agent command (default: `pi`). |
| `AGENT_EVAL_RUNS_DIR` | drivers | Where runs are written (default `eval/runs`). |

## Notes / limitations

- The opaque CLI runner does **not** support AskUserQuestion interception, so the
  wrapper injects a non-interactive system prompt telling the agent not to ask for
  confirmation (both `journal-organize` and `journal-weekly` have confirmation
  gates). Review the resulting outputs when tuning.
- Headless multi-step runs are non-deterministic (the model may narrate a step
  and stop, or a Vertex call may transiently fail). Since a successful run always
  changes the vault, `run-skill.sh` retries when nothing changed
  (`AGENT_EVAL_MAX_ATTEMPTS`, default 3).
- Fixtures use fixed dates (and `args` carry an explicit date / week id) so runs
  are deterministic regardless of the current system date.
- To regenerate or add cases, follow the existing case structure or use the
  harness's `/eval-dataset`.
