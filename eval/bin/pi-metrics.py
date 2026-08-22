#!/usr/bin/env python3
"""Parse a pi `--mode json` event stream into an agent-eval-harness metrics.json.

Usage:
    pi-metrics.py <events.jsonl> <metrics_out.json> [model_hint]

pi emits one JSON object per line (see pi docs/json.md). Assistant messages
carry a `usage` object (docs/session-format.md):

    usage = {input, output, cacheRead, cacheWrite, totalTokens,
             cost: {input, output, cacheRead, cacheWrite, total}}

We prefer the authoritative `agent_end.messages` list; if absent (e.g. the run
errored mid-flight) we fall back to the per-message `message_end` events. Token
and cost totals are summed across assistant messages (and any tool messages that
did nested LLM work), producing the harness metrics.json shape:

    {token_usage:{input,output}, cost_usd, num_turns, model,
     models_used, per_model_usage, per_model_turns}

The final assistant text is printed to stdout so the wrapper can surface it as
the run's stdout.log. Best-effort: never raises; writes what it can.
"""
import json
import sys


def _iter_events(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line.startswith("{"):
                    continue
                try:
                    yield json.loads(line)
                except json.JSONDecodeError:
                    continue
    except OSError:
        return


def main():
    if len(sys.argv) < 3:
        return
    events_path, metrics_out = sys.argv[1], sys.argv[2]
    model_hint = sys.argv[3] if len(sys.argv) > 3 else ""

    by_id = {}          # message_end fallback, keyed by id (dedupes)
    agent_end_msgs = None
    turns = 0
    for ev in _iter_events(events_path):
        t = ev.get("type")
        if t == "turn_end":
            turns += 1
        elif t == "message_end":
            m = ev.get("message") or {}
            by_id[m.get("id") or len(by_id)] = m
        elif t == "agent_end":
            agent_end_msgs = ev.get("messages") or []

    msgs = agent_end_msgs if agent_end_msgs is not None else list(by_id.values())

    tot_in = tot_out = 0
    tot_cost = 0.0
    per_model = {}
    per_model_turns = {}
    last_model = ""
    for m in msgs:
        usage = m.get("usage")
        if not isinstance(usage, dict):
            continue
        model = m.get("model") or ""
        ci = int(usage.get("input") or 0)
        co = int(usage.get("output") or 0)
        cost = 0.0
        c = usage.get("cost")
        if isinstance(c, dict):
            cost = float(c.get("total") or 0.0)
        tot_in += ci
        tot_out += co
        tot_cost += cost
        if m.get("role") == "assistant":
            last_model = model or last_model
            if model:
                per_model_turns[model] = per_model_turns.get(model, 0) + 1
        if model:
            pm = per_model.setdefault(model, {"input": 0, "output": 0, "cost_usd": 0.0})
            pm["input"] += ci
            pm["output"] += co
            pm["cost_usd"] = round(pm["cost_usd"] + cost, 6)

    # Final assistant text (last assistant message's text blocks).
    final_text = ""
    for m in reversed(msgs):
        if m.get("role") == "assistant":
            parts = [b.get("text", "") for b in (m.get("content") or [])
                     if isinstance(b, dict) and b.get("type") == "text"]
            if parts:
                final_text = "".join(parts).strip()
                break

    metrics = {
        "token_usage": {"input": tot_in, "output": tot_out},
        "cost_usd": round(tot_cost, 6),
        "num_turns": turns or sum(per_model_turns.values()),
        "model": last_model or model_hint,
    }
    if per_model:
        metrics["models_used"] = sorted(per_model)
        metrics["per_model_usage"] = per_model
        metrics["per_model_turns"] = per_model_turns

    try:
        with open(metrics_out, "w") as f:
            json.dump(metrics, f)
    except OSError:
        pass

    if final_text:
        print(final_text)


if __name__ == "__main__":
    main()
