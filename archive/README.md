# Archived observability

The benchmark host is ephemeral - its local NVMe is wiped on teardown and the
Prometheus history would go with it. **`prometheus-data.tgz` is committed**, so
this repository carries the actual time-series behind every figure in the report,
not just the tooling to produce more.

## Replay the real runs

```bash
mkdir -p prom-data
tar xzf prometheus-data.tgz -C prom-data
docker compose up -d
open http://localhost:3000        # admin / admin
```

Grafana starts empty and provisions its datasource and dashboards from
[`../observability/grafana/`](../observability/grafana/), so every panel appears
exactly as it did live - no Grafana state needs shipping.

Set the dashboard time range to cover the benchmark window; each series carries a
`level="fp16-L2-kv"` label, so **baseline and every iteration sit on the same
axes**, paired with GPU telemetry from DCGM.

## What is here and why

| | Committed | Why |
|---|---|---|
| `prometheus-data.tgz` | **yes** - 322 KB | The measurements. Without it a clone replays an empty dashboard |
| `docker-compose.yml`, `prometheus.yml` | yes | The replay stack |
| Grafana state | **no** | 20 MB of bundled plugin assets plus `grafana.db`, which holds the admin credential hash - and redundant, since dashboards are code |

## Two views of the same runs

| Source | Shows |
|---|---|
| `bench/out/*.json` | Per-level aggregates - throughput, TTFT percentiles, TPOT, failures |
| This archive | The **timeline** - KV cache filling, preemptions starting, NVLink traffic, tensor-pipe activity, all against wall clock |

The aggregates say what happened. The timeline shows the engine getting there.
