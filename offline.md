# Endpoints are offline

The exercise ran on a rented GPU host. It was released once the benchmark
completed rather than left idle, so these no longer answer:

| | URL |
|---|---|
| Chat UI | `chat.zinalacina.com` |
| OpenAI-compatible API | `llm.zinalacina.com/v1` - bearer token |
| Grafana - all levels on shared panels | `llm-dash.zinalacina.com` |

**Nothing in [`REPORT.md`](REPORT.md) depends on them.** Every figure is
generated from `bench/out/`, and the dashboards replay from a Prometheus
snapshot committed to this repository. This file is how to reach both.

---

## The dashboards

`archive/prometheus-data.tgz` is the time-series database from the actual run.
Grafana provisions its datasource and dashboards from `observability/grafana/`,
so no Grafana state needs shipping.

```bash
cd archive
mkdir -p prom-data && tar xzf prometheus-data.tgz -C prom-data
docker compose up -d
open http://localhost:3000        # admin / admin
```

Every series carries a `level` label, so the baseline and each tuning level sit
on the same panels exactly as they did live. Set the dashboard time range to the
run window - each benchmark level is only a few minutes long.

`docker compose down` in the same directory stops it.

## The numbers

`bench/out/` holds one JSON per configuration. Each carries the model, flags,
environment and workload that produced it, next to the results it produced - so
configuration cannot drift from its numbers:

```bash
jq '{flags, levels: [.levels[] | {concurrency, output_tok_per_s, ttft_ms}]}' \
   bench/out/fp16-L3-schedule.json

python3 bench/report.py        # regenerates RESULTS.md from those files
```

`bench/out/<level>.startup.txt` holds vLLM's own sizing decisions - KV cache size
and reported maximum concurrency. That is the engine's accounting rather than an
inference drawn from throughput, and it is what the report cites.

## Running it yourself

The load generator works standalone against any endpoint. Bring vLLM up per
[`README.md`](README.md), then:

```bash
pip install aiohttp
make ping                                    # up? what is it serving?
make loadtest                                # 4:64,64:256 - the report's levels
make loadtest LEVELS=256:512 PROMPT=2048 OUTPUT=512
```

It defaults to `http://localhost:8000/v1`; `URL=` and `KEY=` point it elsewhere.
Driving it across a network puts the round trip inside TTFT, which the on-box
measurements do not - so compare the *shape* across concurrency levels rather
than absolute milliseconds.
