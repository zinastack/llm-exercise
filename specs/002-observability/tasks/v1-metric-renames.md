# v1 - vLLM renamed the metrics

**Changes from [v0](v0-initial.md)**

## Problem

The **KV cache utilisation panel was empty** - the single most important panel in
the dashboard, since every tuning level in this exercise is a fight for KV
headroom.

vLLM renamed metrics between releases:

| Dashboard queried | Server actually exposes |
|---|---|
| `vllm:gpu_cache_usage_perc` | **`vllm:kv_cache_usage_perc`** |
| `vllm:time_per_output_token_seconds` | **`vllm:inter_token_latency_seconds`** |

## Why it went unnoticed

**A renamed metric produces an empty panel, not an error.** Prometheus returns no
series, Grafana draws nothing, and there is no failure anywhere to notice. It
looks identical to "the workload did not exercise this."

Two panels - KV utilisation and TPOT - were silently blank across every run.

## Change

Corrected in `observability/make_dashboard.py`, which is why the fix is one edit
and a regeneration rather than clicking through Grafana. The verification command
is now in that file's docstring:

```bash
curl -s localhost:8000/metrics | grep -oE '^vllm:[a-z_]+' | sort -u
```

## Operational note

**Dashboards fail silently and should be verified against the running server, not
assumed.** Anything defined against a third-party metric name is a version
dependency, and it deserves the same scrutiny as a pinned image digest - which
this project applies to the container and had not applied to the metric names.
