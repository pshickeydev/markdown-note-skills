---
name: eval-dataset
description: >-
  Add or generate evaluation test cases for a journal skill's eval — each case
  is an input.yaml plus a throwaway vault fixture, a reference output, and
  annotations. Use when asked to add test cases, expand the eval dataset, or
  cover a new scenario. Follows this repo's hand-authored fixture convention.
metadata:
  author: pshickeydev
  version: "1.0"
---

# eval-dataset (Pi orchestrator)

Cases live at `eval/<skill>/dataset/cases/<NNN-slug>/`. Our datasets are
**hand-authored** (the harness's default `skill` provenance), because each case
needs a self-contained Obsidian vault fixture.

## Case layout (copy an existing case as a template)
```
eval/<skill>/dataset/cases/<NNN-slug>/
  input.yaml         # args: "<skill args>"; fixture: eval/<skill>/dataset/cases/<NNN-slug>/vault; target: journals/<...>.md
  vault/             # templates/ (daily.md, weekly.md, topic.md) + journals/ (+ topics/ for weekly)
  reference/         # illustrative gold output (the *_quality judge is reference-free)
  annotations.yaml   # expected bullets/headings/invariants the deterministic judges read
```

## To add a case
1. `cp -r` an existing case dir under the same skill to a new `NNN-slug`.
2. Edit `input.yaml` (args/fixture/target — keep `fixture` pointing at the new dir's `vault`).
3. Seed `vault/journals/…` with the scenario; keep `vault/templates/` intact.
4. Update `annotations.yaml` (targets, `expected_bullets`, `must_retain`, `min_headings`, `journals_must_retain`, …) so the deterministic judges assert the new expectations.
5. Write a `reference/` output for readability.
6. Smoke-test just that case: `/skill:eval-run <skill> --cases <NNN-slug> --no-llm-judges`.

Use fixed dates / explicit week ids in `args` so runs stay deterministic.

## Synthetic generation (not our default)
Only for configs with a `generation:` block (LLM-authored cases). List builtin
prompts / run the generator via the harness:
```bash
eval/bin/harness.sh skills/eval-dataset/scripts/list_prompts.py
eval/bin/harness.sh skills/eval-dataset/scripts/generate_synthetic.py --help
```
