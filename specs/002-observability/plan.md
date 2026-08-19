# 002 - Plan

| Component | Choice | Mechanism |
|---|---|---|
| Serving metrics | vLLM `/metrics` | TTFT, TPOT, KV usage, preemptions, queue depth - already exported |
| GPU telemetry | DCGM exporter | `PIPE_TENSOR_ACTIVE` distinguishes *busy* from *productive*; NVLink byte counters answer the interconnect question visually |
| Per-level labelling | Prometheus **file_sd**, rewritten by `scripts/run.sh` | Stamps `level="fp16-L2-kv"` on every series. One label is what puts all levels on one panel |
| Dashboards | `observability/make_dashboard.py` | PromQL is the substance; generating JSON keeps it reviewable in diff |
| Survival | `make archive` → `archive/docker-compose.yml` | Local NVMe is ephemeral; TSDB and Grafana state copied off, replayable anywhere |

## Risk

Moving the compose file renames the project and orphans named volumes -
destroying all history. Mitigated by pinning `name: observability`.
