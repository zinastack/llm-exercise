# 002 - Tasks

- [x] Prometheus with 5s scrape and file-based discovery
- [x] DCGM exporter
- [x] `scripts/run.sh` rewrites the target file per level, stamping `level=`
- [x] Dashboard generated from PromQL in `observability/make_dashboard.py` - 11 panels
- [x] `make archive` - TSDB + Grafana state + results pulled locally
- [x] `archive/docker-compose.yml` replays offline
- [x] **Near-miss:** moving `docker-compose.yml` to root renamed the compose
      project and would have orphaned `observability_prom-data`. Pinned
      `name: observability`
