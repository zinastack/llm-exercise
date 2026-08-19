#!/usr/bin/env python3
"""Generates the dashboard json. Panels are repetitive, the promql isn't.

Everything groups by the level label so all runs land on the same charts.

vllm renames metrics between releases and a bad name gives you an empty panel,
not an error. check before believing a blank chart:
    curl -s localhost:8000/metrics | grep -oE '^vllm:[a-z_]+' | sort -u
"""
import json, pathlib

DS = {"type": "prometheus", "uid": "${DS_PROMETHEUS}"}
LEGEND = "{{level}}"


def target(expr, legend=LEGEND, ref="A"):
    return {"datasource": DS, "expr": expr, "legendFormat": legend,
            "refId": ref, "range": True}


def panel(title, x, y, w, h, targets, unit="short", desc="", decimals=None,
          ptype="timeseries", fill=8):
    p = {
        "type": ptype, "title": title, "datasource": DS,
        "gridPos": {"x": x, "y": y, "w": w, "h": h},
        "description": desc,
        "targets": targets,
        "options": {
            "legend": {"displayMode": "table", "placement": "bottom",
                       "calcs": ["mean", "max"], "showLegend": True},
            "tooltip": {"mode": "multi", "sort": "desc"},
        },
        "fieldConfig": {
            "defaults": {
                "unit": unit,
                "custom": {
                    "lineWidth": 2, "fillOpacity": fill,
                    "showPoints": "never", "spanNulls": True,
                },
            },
            "overrides": [],
        },
    }
    if decimals is not None:
        p["fieldConfig"]["defaults"]["decimals"] = decimals
    if ptype == "stat":
        p["options"] = {"reduceOptions": {"calcs": ["lastNotNull"],
                                          "fields": "", "values": False},
                        "colorMode": "value", "graphMode": "area",
                        "textMode": "auto"}
    return p


def row(title, y):
    return {"type": "row", "title": title, "collapsed": False,
            "gridPos": {"x": 0, "y": y, "w": 24, "h": 1}, "panels": []}


def quantile(q, metric):
    return (f'histogram_quantile({q}, sum(rate({metric}_bucket[1m])) '
            f'by (le, level))')


panels = []
y = 0

# ── headline ────────────────────────────────────────────────────────────────
panels.append(row("Headline - the two metrics the exercise is scored on", y)); y += 1

panels.append(panel(
    "Output token throughput", 0, y, 12, 8,
    [target("sum by (level) (rate(vllm:generation_tokens_total[1m]))")],
    unit="none", decimals=0,
    desc=("Output tokens per second, by tuning level. This is the throughput "
          "number in the deliverable. Higher is better.")))

panels.append(panel(
    "TTFT p99", 12, y, 12, 8,
    [target(quantile(0.99, "vllm:time_to_first_token_seconds"))],
    unit="s", decimals=3,
    desc=("Tail time-to-first-token. The mean hides queueing; p99 is what a "
          "user complains about. Lower is better.")))
y += 8

panels.append(panel(
    "TTFT percentiles - p50 / p95 / p99", 0, y, 12, 8,
    [target(quantile(0.50, "vllm:time_to_first_token_seconds"), "p50 {{level}}", "A"),
     target(quantile(0.95, "vllm:time_to_first_token_seconds"), "p95 {{level}}", "B"),
     target(quantile(0.99, "vllm:time_to_first_token_seconds"), "p99 {{level}}", "C")],
    unit="s", decimals=3,
    desc=("A widening gap between p50 and p99 is queueing, not slow compute. "
          "Chunked prefill should compress the tail far more than the median.")))

panels.append(panel(
    "TPOT p50 / p99", 12, y, 12, 8,
    [target(quantile(0.50, "vllm:inter_token_latency_seconds"), "p50 {{level}}", "A"),
     target(quantile(0.99, "vllm:inter_token_latency_seconds"), "p99 {{level}}", "B")],
    unit="s", decimals=4,
    desc=("Inter-token latency - the memory-bandwidth-bound decode phase. "
          "This is the metric most sensitive to losing NVLink.")))
y += 8

# ── why ─────────────────────────────────────────────────────────────────────
panels.append(row("Why - KV cache is the binding constraint", y)); y += 1

panels.append(panel(
    "KV cache utilisation", 0, y, 8, 7,
    [target("vllm:kv_cache_usage_perc")],
    unit="percentunit", decimals=2,
    desc=("Pinned near 1.0 means the batch ceiling is KV-bound. Every tuning "
          "level in this exercise is a fight for headroom here.")))

panels.append(panel(
    "Preemptions", 8, y, 8, 7,
    [target("sum by (level) (rate(vllm:num_preemptions_total[1m]))")],
    unit="none", decimals=2,
    desc=("Non-zero means the engine admitted more work than cache could hold "
          "and is recomputing. This is the mechanism that makes throughput "
          "FALL with load rather than plateau.")))

panels.append(panel(
    "Running vs waiting requests", 16, y, 8, 7,
    [target("sum by (level) (vllm:num_requests_running)", "running {{level}}", "A"),
     target("sum by (level) (vllm:num_requests_waiting)", "waiting {{level}}", "B")],
    unit="none", decimals=0,
    desc="Waiting depth is queueing - the direct cause of a bad TTFT tail."))
y += 7

# ── gpu ─────────────────────────────────────────────────────────────────────
panels.append(row("GPU - busy is not the same as productive", y)); y += 1

panels.append(panel(
    "Tensor pipe active vs GPU utilisation", 0, y, 12, 7,
    [target("avg by (gpu) (DCGM_FI_PROF_PIPE_TENSOR_ACTIVE)", "tensor active gpu{{gpu}}", "A"),
     target("avg by (gpu) (DCGM_FI_DEV_GPU_UTIL) / 100", "GPU_UTIL gpu{{gpu}}", "B")],
    unit="percentunit", decimals=3,
    desc=("GPU_UTIL only means a kernel was resident. Decode is memory-bound, "
          "so high utilisation with low tensor activity is expected here - not "
          "a fault, and mistaking it for one sends you optimising the wrong "
          "thing.")))

panels.append(panel(
    "NVLink traffic", 12, y, 12, 7,
    [target("sum by (gpu) (rate(DCGM_FI_PROF_NVLINK_TX_BYTES[1m]))", "tx gpu{{gpu}}", "A"),
     target("sum by (gpu) (rate(DCGM_FI_PROF_NVLINK_RX_BYTES[1m]))", "rx gpu{{gpu}}", "B")],
    unit="Bps",
    desc=("Tensor parallelism does ~160 all-reduces per forward pass across 80 "
          "layers. This panel goes to roughly zero on the nvlink-off control, "
          "which is the visual answer to the NVLink question.")))
y += 7

panels.append(panel(
    "GPU memory used", 0, y, 12, 6,
    [target("DCGM_FI_DEV_FB_USED * 1024 * 1024", "gpu{{gpu}}")],
    unit="bytes",
    desc="Weights plus KV cache. INT4 quantization is visible here directly."))

panels.append(panel(
    "GPU power", 12, y, 12, 6,
    [target("DCGM_FI_DEV_POWER_USAGE", "gpu{{gpu}}")],
    unit="watt", decimals=0,
    desc="Sustained draw. A pair of throttling A100s shows up here first."))
y += 6

dashboard = {
    "title": "LLM Serving - tuning levels",
    "uid": "llm-serving-levels",
    "tags": ["exercise", "vllm", "a100"],
    "timezone": "browser",
    "schemaVersion": 39,
    "version": 1,
    "refresh": "10s",
    "time": {"from": "now-1h", "to": "now"},
    "editable": True,
    "graphTooltip": 1,          # shared crosshair across panels
    "templating": {"list": [
        {"name": "DS_PROMETHEUS", "type": "datasource", "query": "prometheus",
         "current": {"text": "Prometheus", "value": "Prometheus"}, "hide": 0},
        {"name": "level", "type": "query", "datasource": DS,
         "query": "label_values(vllm:num_requests_running, level)",
         "refresh": 1, "multi": True, "includeAll": True,
         "current": {"text": "All", "value": "$__all"}},
    ]},
    "annotations": {"list": [{
        "name": "Level changes", "datasource": DS, "enable": True,
        "iconColor": "rgba(255, 96, 96, 1)",
        "expr": "changes(vllm:num_requests_running[1m]) > bool 0",
        "titleFormat": "level: {{level}}",
    }]},
    "panels": panels,
}

dest = pathlib.Path(__file__).parent / "grafana" / "dashboards" / "serving-levels.json"
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(dashboard, indent=2))
print(f"wrote {dest}  ({len([p for p in panels if p['type'] != 'row'])} panels)")
