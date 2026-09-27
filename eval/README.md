# Evaluations

This directory holds the **journal-skill eval configs and datasets** for the
[agent-eval-harness](https://github.com/opendatahub-io/agent-eval-harness)
(pinned to **v1.41.0**). The pi-specific wiring — runner/judge wrappers, the
pipeline driver, and the `/skill:eval-*` orchestrator skills — lives in the
[`vendor/pi-agent-eval-harness`](../vendor/pi-agent-eval-harness) submodule
([pi-agent-eval-harness](https://github.com/pshickeydev/pi-agent-eval-harness));
see its README for the runner model, provider/region setup, environment
variables, and the general conventions. This file covers what is specific to
*this* repo.

## Harness version (pinned)

Verified against **agent-eval-harness `v1.41.0`** (release commit `2a10e504`).
Set `AGENT_EVAL_HARNESS` to a checkout of that tag (cloned + `pip install -e .`).
The pin exists because the configs depend on harness internals that are not a
stable public API (cli-runner agent judges, the reserved `output`/`.context`
names, `.work/` being ignored by `collect.py`, the `{config_dir}` placeholder
and `{{ outputs }}` rendering) — details in the submodule's README.

## Layout

```
eval/
  journal-note/
    eval.yaml                      config for the journal-note skill
    dataset/cases/*/               test cases (input.yaml, fixture vault, reference/, annotations.yaml)
  journal-organize/
    eval.yaml
    dataset/cases/*/
  journal-weekly/
    eval.yaml
    dataset/cases/*/
  runs/                            run outputs (gitignored)

vendor/pi-agent-eval-harness/      submodule: bin/ wrappers + pipeline driver
.pi/skills/eval-*                  symlinks into the submodule's skills/ (pi orchestrators)
```

The Pi **orchestrator** skills live outside `.agents/skills/` (symlinked into
`.pi/skills/` from the submodule) so the runner never copies them into a test
workspace:

```
/skill:eval-run       run eval(s) + interpret results        (-> bin/run-eval.sh)
/skill:eval-setup     preflight env + pi auth                 (-> check_env.py)
/skill:eval-analyze   author / validate an eval.yaml           (-> validate_eval.py)
/skill:eval-dataset   add / generate test cases
/skill:eval-review    human review of a run -> review.yaml
/skill:eval-optimize  run -> diagnose -> edit -> re-run
/skill:eval-compare   HTML comparison across runs              (-> compare.py)
/skill:eval-check     config/reference health scan             (-> reference_checker.py)
/skill:eval-mlflow    log results / feedback to MLflow          (-> log_results.py)
/skill:eval-anova     matrix DoE + ANOVA (advanced)             (-> orchestrate.py)
```

All require `AGENT_EVAL_HARNESS` (upstream harness checkout) and are discovered
by pi once the project is trusted (`pi --approve`).

Each case is self-contained:

| File | Purpose |
|------|---------|
| `input.yaml` | `args` (skill arguments), `fixture` (repo-relative vault dir), `target` (file the skill writes) |
| `vault/` | throwaway Obsidian vault fixture — `templates/`, `journals/`, and sometimes `topics/` |
| `reference/` | example gold-standard output (illustrative; the quality judge is reference-free) |
| `annotations.yaml` | expected bullets / headings / invariants for the deterministic judges |

## This repo's runner configuration

The three `eval.yaml` files set the journal-specific env vars consumed by the
submodule's `run-skill.sh` (see the submodule README's "Project-specific
behaviour" table):

- `AGENT_EVAL_AGENTS_MD` — a `## Vault Location` AGENTS.md pointing at the
  staged fixture vault, written at the staging root so every resolution path
  (skill-relative `../../../AGENTS.md`, git root, cwd) lands on the fixture,
- `AGENT_EVAL_RUNNER_GUIDANCE` — scopes the agent strictly to the staged vault,
- `AGENT_EVAL_ARTIFACT_DIRS` — mirrors `journals/ summaries/ topics/` into the
  collected artifacts.

## ⚠️ Vault isolation (read this)

The journal skills resolve the vault from `AGENTS.md`, and they check the copy
at `../../../AGENTS.md` **relative to the `SKILL.md` file** (and the git root)
*before* the current directory. This repo's own `AGENTS.md` points at your real
Obsidian vault. The submodule's runner wrapper prevents leakage by staging an
isolated fixture + skills copy + generated `AGENTS.md` under the workspace
`.work/` per case — but your agent must load the skill from `{skill_dir}`
(pi does via `--skill {skill_dir}`). A `WARNING` about the repo `AGENTS.md`
pointing elsewhere during a run is expected and harmless. See the submodule
README's "Isolation safety" section before pointing a custom `AGENT_EVAL_CLI`
near a real vault.

## Running

```bash
export AGENT_EVAL_HARNESS=/path/to/agent-eval-harness   # cloned + pip install -e, at v1.41.0
git submodule update --init                             # first checkout

# A. pi as orchestrator (launch `pi --approve`, then in the session):
/skill:eval-setup
/skill:eval-run journal-note --no-llm-judges     # fast structural pass
/skill:eval-run journal-note                    # full run (with the pi agent judge)

# B. direct driver (scriptable, no orchestrator agent):
vendor/pi-agent-eval-harness/bin/run-eval.sh --config eval/journal-note/eval.yaml --no-llm-judges
vendor/pi-agent-eval-harness/bin/run-eval.sh --config eval/journal-weekly/eval.yaml \
  --model anthropic-vertex/claude-sonnet-4-6
```

Outputs land in `eval/runs/<eval-name>/<run-id>/` (`summary.yaml`, `report.html`).

Model/provider notes (the `anthropic-vertex/` prefix, the Vertex region pin,
`us-east5` vs the flaky `global` location, and how to relaunch the orchestrator
session pinned to a reliable model pair) are in the submodule's README — this
repo's models are region-split: `claude-opus-4-6`/`claude-sonnet-4-6` are in
**`us-east5`**; `claude-opus-4-8` is only in `global`.

## Notes / limitations

- Deterministic judges (`check:`) run without any API key and enforce the hard
  invariants (note appended, content preserved, headings added, journals never
  modified). The `*_quality` agent judges make model calls; skip them with
  `--no-llm-judges`.
- The opaque CLI runner does **not** support AskUserQuestion interception, so
  the wrapper injects a non-interactive system prompt (both `journal-organize`
  and `journal-weekly` have confirmation gates). Review the resulting outputs
  when tuning.
- Headless multi-step runs are non-deterministic; the wrapper retries when a
  run leaves the vault unchanged (`AGENT_EVAL_MAX_ATTEMPTS`, default 3).
- Fixtures use fixed dates (and `args` carry an explicit date / week id) so runs
  are deterministic regardless of the current system date.
- To regenerate or add cases, follow the existing case structure or use
  `/skill:eval-dataset`.
